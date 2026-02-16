# Infrastructure - Documentation complète

## Vue d'ensemble

L'infrastructure DevBoard est déployée sur **Proxmox** avec **Terraform** pour l'IaC, **Ansible** pour la configuration, et **K3s** pour l'orchestration Kubernetes.

---

## Architecture Infrastructure

```
┌─────────────────────────────────────────────────────┐
│                   Proxmox Host                       │
│                   (proxade)                          │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  │  LXC 400     │  │  LXC 401     │  │  LXC 402     │
│  │              │  │              │  │              │
│  │ K3s Server   │  │ K3s Agent 1  │  │ K3s Agent 2  │
│  │ (Master)     │  │ (Worker)     │  │ (Worker)     │
│  │              │  │              │  │              │
│  │ 192.168.1.40 │  │ 192.168.1.41 │  │ 192.168.1.42 │
│  │ 4 CPU        │  │ 4 CPU        │  │ 4 CPU        │
│  │ 4096 MB RAM  │  │ 3072 MB RAM  │  │ 3072 MB RAM  │
│  │ 32 GB Disk   │  │ 32 GB Disk   │  │ 32 GB Disk   │
│  └──────────────┘  └──────────────┘  └──────────────┘
│                                                      │
└─────────────────────────────────────────────────────┘
```

---

## 1. Terraform - Provisioning des LXC

### 📁 Emplacement
`infra/terraform/`

### 🎯 Rôle
Crée les containers LXC sur Proxmox via l'API.

### 📋 Ressources créées

| VMID | Nom         | Rôle        | IP           | CPU | RAM  | Disk |
|------|-------------|-------------|--------------|-----|------|------|
| 400  | k3s-server  | Control Plane | 192.168.1.40 | 4   | 4GB  | 32GB |
| 401  | k3s-agent-1 | Worker      | 192.168.1.41 | 4   | 3GB  | 32GB |
| 402  | k3s-agent-2 | Worker      | 192.168.1.42 | 4   | 3GB  | 32GB |

### ⚙️ Configuration LXC pour K3s

Les containers nécessitent des configurations spécifiques pour exécuter K3s :

```conf
# Configuration LXC (/etc/pve/lxc/400.conf)
unprivileged: 0                          # Mode privileged requis
features: fuse=1,keyctl=1,mknod=1,nesting=1
lxc.mount.auto: proc:rw sys:rw cgroup:rw # /proc et /sys en écriture
lxc.apparmor.profile: unconfined         # Désactiver apparmor
lxc.cap.drop:                            # Garder toutes les capabilities
```

**Fixes critiques appliqués** :
- `/dev/kmsg` : `ln -sf /dev/console /dev/kmsg` (requis par kubelet)
- `iptables` : Installation requise pour le réseau K3s
- Procfs/Sysfs RW : Requis pour les paramètres kernel

### 🚀 Commandes Terraform

```bash
cd infra/terraform

# Initialiser Terraform
terraform init

# Planifier les changements
terraform plan

# Appliquer la configuration
terraform apply

# Détruire l'infrastructure
terraform destroy
```

### 🔧 Variables Terraform

Les variables sont dans `variables.tf` :
- `proxmox_api_url` : URL de l'API Proxmox
- `proxmox_token_id` : ID du token API
- `proxmox_token_secret` : Secret du token
- `target_node` : Nom du nœud Proxmox cible

---

## 2. Ansible - Configuration et déploiement

### 📁 Emplacement
`infra/ansible/`

### 🎯 Rôle
Configure les LXC et déploie K3s + stack DevOps (Prometheus, Grafana, Loki, Vault).

### 📂 Structure

```
infra/ansible/
├── inventory/
│   └── dev.yml              # Inventaire des hosts
├── playbooks/
│   ├── install-k3s.yml      # Installation K3s
│   └── deploy-tools.yml     # Déploiement des outils
└── roles/
    ├── k3s-server/
    ├── k3s-agent/
    ├── monitoring/
    └── vault/
```

### 📋 Inventaire (`inventory/dev.yml`)

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    k3s_version: v1.31.4+k3s1

  children:
    k3s_server:
      hosts:
        k3s-server:
          ansible_host: 192.168.1.40

    k3s_agents:
      hosts:
        k3s-agent-1:
          ansible_host: 192.168.1.41
        k3s-agent-2:
          ansible_host: 192.168.1.42
```

### 📜 Playbook 1 : Installation K3s

**Fichier** : `playbooks/install-k3s.yml`

**Étapes** :
1. Installation des prérequis (curl, iptables, apparmor)
2. Installation du server K3s sur le nœud 400
3. Récupération du token K3s
4. Téléchargement du kubeconfig
5. Installation des agents K3s sur les nœuds 401-402

**Exécution** :
```bash
cd infra/ansible
ansible-playbook -i inventory/dev.yml playbooks/install-k3s.yml
```

**Résultat** :
- Cluster K3s opérationnel (1 master + 2 workers)
- Kubeconfig disponible : `infra/ansible/kubeconfig.yaml`

### 📜 Playbook 2 : Déploiement des outils

**Fichier** : `playbooks/deploy-tools.yml`

**Étapes** :
1. Installation de Helm
2. Ajout des repos Helm (prometheus-community, grafana, hashicorp)
3. Création des namespaces (devboard-*, monitoring, security)
4. Installation de kube-prometheus-stack (Prometheus + Grafana)
5. Installation de Loki-stack (Loki + Promtail)
6. Installation de Vault (mode dev)

**Exécution** :
```bash
cd infra/ansible
ansible-playbook -i inventory/dev.yml playbooks/deploy-tools.yml
```

**Résultat** :
- Prometheus + Grafana déployés (namespace `monitoring`)
- Loki + Promtail déployés (logs centralisés)
- Vault déployé (namespace `security`)

### 🔑 Accès SSH aux nœuds

```bash
# Server K3s
ssh root@192.168.1.40

# Agents K3s
ssh root@192.168.1.41
ssh root@192.168.1.42
```

---

## 3. K3s - Cluster Kubernetes

### 🎯 Caractéristiques

- **Version** : v1.31.4+k3s1
- **Distribution** : K3s (Kubernetes léger)
- **Container Runtime** : containerd 1.7.23
- **Ingress Controller** : Traefik (inclus)
- **Storage** : local-path-provisioner (inclus)
- **Metrics** : metrics-server (inclus)

### 🏗️ Architecture du cluster

```
┌──────────────────────────────────────────────────┐
│            K3s Server (192.168.1.40)              │
│  ┌────────────────────────────────────────────┐  │
│  │  Control Plane                             │  │
│  │  - API Server                              │  │
│  │  - Scheduler                               │  │
│  │  - Controller Manager                      │  │
│  │  - etcd (embedded)                         │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  Worker Components                         │  │
│  │  - kubelet                                 │  │
│  │  - containerd                              │  │
│  │  - Traefik Ingress Controller              │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
┌─────────▼──────┐       ┌─────────▼──────┐
│  K3s Agent 1   │       │  K3s Agent 2   │
│ (192.168.1.41) │       │ (192.168.1.42) │
│                │       │                │
│  - kubelet     │       │  - kubelet     │
│  - containerd  │       │  - containerd  │
└────────────────┘       └────────────────┘
```

### 📊 État du cluster

```bash
# Vérifier les nœuds
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
kubectl get nodes -o wide

# Résultat attendu :
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-server    Ready    control-plane,master   XXm   v1.31.4+k3s1
# k3s-agent-1   Ready    <none>                 XXm   v1.31.4+k3s1
# k3s-agent-2   Ready    <none>                 XXm   v1.31.4+k3s1
```

### 🔧 Accès au cluster

#### Option 1 : Depuis ta machine locale
```bash
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
kubectl get pods -A
```

#### Option 2 : Depuis le serveur K3s
```bash
ssh root@192.168.1.40
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get pods -A
```

### 📦 Composants système (namespace kube-system)

| Composant                | Rôle                                    |
|-------------------------|-----------------------------------------|
| coredns                 | DNS interne du cluster                  |
| traefik                 | Ingress controller (routing HTTP/HTTPS) |
| metrics-server          | Métriques CPU/RAM des pods              |
| local-path-provisioner  | Dynamic volume provisioning             |
| svclb-traefik-*         | Service LoadBalancer pour Traefik       |

---

## 4. Réseau et Ingress

### 🌐 Réseau interne

- **CNI** : Flannel (inclus dans K3s)
- **Pod CIDR** : 10.42.0.0/16
- **Service CIDR** : 10.43.0.0/16

### 🚪 Ingress Controller : Traefik

Traefik écoute sur le port 80 de **toutes** les IPs du cluster via un Service LoadBalancer.

**Principe** : Virtual Hosting basé sur le header HTTP `Host:`

```yaml
# Exemple d'Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
spec:
  rules:
    - host: grafana.devboard.local
      http:
        paths:
          - backend:
              service:
                name: prometheus-grafana
                port: 80
```

**Accès** : http://grafana.devboard.local (après configuration `/etc/hosts`)

Voir [INGRESS-ROUTING-EXPLAINED.md](INGRESS-ROUTING-EXPLAINED.md) pour les détails.

---

## 5. Dépannage

### Problème : K3s ne démarre pas

**Symptôme** : `open /dev/kmsg: no such file or directory`

**Solution** :
```bash
ssh root@192.168.1.40
ln -sf /dev/console /dev/kmsg
systemctl restart k3s
```

### Problème : "Failed to start ContainerManager" / "read-only file system"

**Cause** : /proc/sys en lecture seule dans le LXC

**Solution** : Ajouter dans `/etc/pve/lxc/400.conf` :
```
lxc.mount.auto: proc:rw sys:rw cgroup:rw
```

Puis redémarrer le container :
```bash
pct stop 400 && pct start 400
```

### Problème : Pods en ImagePullBackOff

**Cause** : Images locales mais imagePullPolicy = Always

**Solution** : Définir `imagePullPolicy: Never` dans les manifests/Helm values.

### Problème : Pas d'accès depuis le navigateur

**Vérifications** :
1. `/etc/hosts` configuré ?
   ```bash
   cat /etc/hosts | grep devboard
   ```
2. Ingress créés ?
   ```bash
   kubectl get ingress -A
   ```
3. Test curl :
   ```bash
   curl -H "Host: grafana.devboard.local" http://192.168.1.40
   ```

---

## 6. Maintenance

### Mettre à jour K3s

```bash
# Sur le server
ssh root@192.168.1.40
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=vX.XX.X+k3s1 sh -

# Sur les agents
ssh root@192.168.1.41
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=vX.XX.X+k3s1 K3S_URL=https://192.168.1.40:6443 K3S_TOKEN=<token> sh -
```

### Sauvegarder le cluster

```bash
# Sauvegarder etcd (données K3s)
ssh root@192.168.1.40
k3s etcd-snapshot save

# Sauvegarder les manifests
kubectl get all -A -o yaml > backup-k8s-resources.yaml
```

### Redémarrer les services

```bash
# Redémarrer K3s
ssh root@192.168.1.40 "systemctl restart k3s"

# Redémarrer un deployment
kubectl rollout restart deployment <name> -n <namespace>
```

---

## 7. Commandes utiles

```bash
# État du cluster
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Logs d'un service K3s
ssh root@192.168.1.40 "journalctl -u k3s.service -f"

# Kubeconfig
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml

# Helm
helm list -A
helm upgrade --install <release> <chart> -f values.yaml -n <namespace>

# Images dans K3s
ssh root@192.168.1.40 "k3s ctr images ls"
```

---

## 📚 Références

- [K3s Documentation](https://docs.k3s.io/)
- [Traefik Kubernetes Ingress](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
- [Proxmox LXC](https://pve.proxmox.com/wiki/Linux_Container)
- [Ansible Documentation](https://docs.ansible.com/)
