# Services disponibles - DevBoard

## 🌐 Accès aux services (sans localhost)

### Configuration requise sur votre machine
Ajouter dans `/etc/hosts` (Linux/Mac) ou `C:\Windows\System32\drivers\etc\hosts` (Windows) :
```
192.168.40.40 dev.devboard.local
192.168.40.40 grafana.devboard.local
192.168.40.40 prometheus.devboard.local
192.168.40.40 alertmanager.devboard.local
192.168.40.40 vault.devboard.local
```

**Note** : Vous pouvez utiliser n'importe quelle IP des nœuds (192.168.40.40, .41 ou .42)

---

## Application DevBoard

### 🌍 Accès web direct
- **URL** : http://dev.devboard.local
  - Frontend sur `/`
  - Backend API sur `/api/`

### Endpoints santé
- **Backend health** : http://dev.devboard.local/api/health
- **Backend ready** : http://dev.devboard.local/api/ready
- **Backend metrics** : http://dev.devboard.local/api/metrics

---

## 📊 Monitoring

### Grafana
- **URL directe** : http://grafana.devboard.local
- **Credentials** :
  - Username : `admin`
  - Password : `admin`
- **Alternative (port-forward)** :
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
  # Accès : http://localhost:3000
  ```

### Prometheus
- **URL directe** : http://prometheus.devboard.local
- **Alternative (port-forward)** :
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
  # Accès : http://localhost:9090
  ```

### Alertmanager
- **URL directe** : http://alertmanager.devboard.local
- **Alternative (port-forward)** :
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
  # Accès : http://localhost:9093
  ```

### Loki (Logs)
- **Configuration Grafana** : 
  - Aller dans Grafana → Configuration → Data Sources → Add data source → Loki
  - URL : `http://loki.monitoring.svc.cluster.local:3100`
  - Pas d'accès web direct (API uniquement)

---

## 🔐 Sécurité

### Vault
- **URL directe** : http://vault.devboard.local
- **Token root** : `root` (mode dev uniquement !)
- **Alternative (port-forward)** :
  ```bash
  kubectl port-forward -n security svc/vault 8200:8200
  # Accès : http://localhost:8200
  ```
- **CLI Vault** :
  ```bash
  export VAULT_ADDR=http://vault.devboard.local
  export VAULT_TOKEN=root
  vault kv list secret/devboard/
  ```

### Secrets stockés dans Vault
- `secret/devboard/db` → Credentials PostgreSQL
- `secret/devboard/jwt` → Secret JWT pour l'authentification

---

## Infrastructure K3s
- **Cluster** : 3 nœuds (1 server + 2 agents)
- **IP K3s Server** : `192.168.40.40`
- **IP K3s Agent 1** : `192.168.40.41`
- **IP K3s Agent 2** : `192.168.40.42`

### Pods et services internes
```bash
kubectl get pods -n devboard-dev
# devboard-backend    → API REST (port 8080)
# devboard-frontend   → Interface React (port 80)
# devboard-postgres   → Base de données PostgreSQL (port 5432)
```

---

## Monitoring (namespace: monitoring)

**Services internes** :

- `prometheus-grafana.monitoring.svc.cluster.local:80`
- `prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090`
- `prometheus-kube-prometheus-alertmanager.monitoring.svc.cluster.local:9093`
- `loki.monitoring.svc.cluster.local:3100`

---

## Sécurité (namespace: security)

**Services internes** :
- `vault.security.svc.cluster.local:8200`

---

## 🔧 Accès SSH aux nœuds K3s

```bash
# Server
ssh root@192.168.40.40

# Agents
ssh root@192.168.40.41
ssh root@192.168.40.42
```

## Kubeconfig

Le kubeconfig est disponible localement :
```bash
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

Ou directement sur le serveur K3s :
```bash
ssh root@192.168.40.40
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

## Commandes utiles

```bash
# Voir tous les pods
kubectl get pods -A

# Logs d'un pod
kubectl logs -n devboard-dev <pod-name>

# Logs en continu
kubectl logs -n devboard-dev <pod-name> -f

# Restart un deployment
kubectl rollout restart deployment devboard-backend -n devboard-dev

# État du cluster
kubectl get nodes
kubectl top nodes  # Nécessite metrics-server (déjà installé)
kubectl top pods -A

# Helm releases
helm list -A
```

## Namespaces

- `devboard-dev` → Application DevBoard (dev)
- `devboard-staging` → Staging (vide pour l'instant)
- `devboard-prod` → Production (vide pour l'instant)
- `monitoring` → Prometheus, Grafana, Loki, Alertmanager
- `security` → Vault
- `kube-system` → Services K3s (CoreDNS, Traefik, metrics-server)
