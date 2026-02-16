# Identifiants et Accès - Guide Rapide

## 🔑 Credentials des services

### Grafana
- **URL** : http://grafana.devboard.local
- **Username** : `admin`
- **Password** : `admin`
- **Note** : Changez le mot de passe à la première connexion en production

**Récupérer le mot de passe via kubectl** :
```bash
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

---

### Prometheus
- **URL** : http://prometheus.devboard.local
- **Authentication** : Aucune (accès libre)
- **Note** : Protéger avec auth en production

---

### Alertmanager
- **URL** : http://alertmanager.devboard.local
- **Authentication** : Aucune (accès libre)

---

### Vault
- **URL** : http://vault.devboard.local
- **Token root** : `root`
- **Mode** : dev (⚠️ NON sécurisé pour production)
- **Unsealed** : Automatiquement (mode dev)

**Utilisation CLI** :
```bash
export VAULT_ADDR=http://vault.devboard.local
export VAULT_TOKEN=root

vault status
vault kv list secret/devboard/
```

---

### DevBoard Application

#### Base de données PostgreSQL
- **Host** : `devboard-postgres` (internal K8s)
- **Port** : `5432`
- **Database** : `devboard`
- **Username** : `devboard`
- **Password** : `devboard-secret`

**Connexion depuis un pod** :
```bash
kubectl exec -it <postgres-pod> -n devboard-dev -- \
  psql -U devboard -d devboard
```

**Connection string complète** :
```
postgres://devboard:devboard-secret@devboard-postgres:5432/devboard?sslmode=disable
```

#### JWT Secret
- **Secret** : `changeme-jwt-secret-minimum-32-chars`
- **Usage** : Signature des tokens JWT (quand auth activée)
- **⚠️** : À changer en production !

---

### SSH Accès aux nœuds K3s

#### K3s Server (Control Plane)
```bash
ssh root@192.168.1.40
```

#### K3s Agent 1 (Worker)
```bash
ssh root@192.168.1.41
```

#### K3s Agent 2 (Worker)
```bash
ssh root@192.168.1.42
```

**Note** : Authentification par clé SSH (configurée via Terraform/Ansible)

---

## 📦 Secrets stockés dans Vault

### Lire les secrets depuis Vault

```bash
export VAULT_ADDR=http://vault.devboard.local
export VAULT_TOKEN=root

# Database credentials
vault kv get secret/devboard/db
# Output:
# Key         Value
# ---         -----
# database    devboard
# host        postgres
# password    devboard-secret
# port        5432
# username    devboard

# JWT secret
vault kv get secret/devboard/jwt
# Output:
# Key       Value
# ---       -----
# secret    changeme-jwt-secret-minimum-32-chars
```

---

## 🔐 Secrets Kubernetes

### Lire le secret principal

```bash
# Voir tous les secrets
kubectl get secrets -n devboard-dev

# Voir le contenu (base64 encodé)
kubectl get secret devboard-secrets -n devboard-dev -o yaml

# Décoder un secret spécifique
kubectl get secret devboard-secrets -n devboard-dev \
  -o jsonpath='{.data.db-password}' | base64 -d
echo

# Décoder tous les secrets
kubectl get secret devboard-secrets -n devboard-dev -o json | \
  jq -r '.data | map_values(@base64d)'
```

### Contenu du secret `devboard-secrets`

| Clé | Valeur | Usage |
|-----|--------|-------|
| `db-username` | `devboard` | PostgreSQL username |
| `db-password` | `devboard-secret` | PostgreSQL password |
| `database-url` | `postgres://devboard:devboard-secret@devboard-postgres:5432/devboard?sslmode=disable` | Connection string complète |
| `jwt-secret` | `changeme-jwt-secret-minimum-32-chars` | JWT signing key |

---

## 🌐 URLs d'accès (après config /etc/hosts)

### Configuration requise dans /etc/hosts

```bash
# Ajouter ces lignes dans /etc/hosts
192.168.1.40 dev.devboard.local
192.168.1.40 grafana.devboard.local
192.168.1.40 prometheus.devboard.local
192.168.1.40 alertmanager.devboard.local
192.168.1.40 vault.devboard.local
```

**Commande rapide** :
```bash
sudo bash -c 'cat >> /etc/hosts << EOF

# DevBoard K3s Services
192.168.1.40 dev.devboard.local
192.168.1.40 grafana.devboard.local
192.168.1.40 prometheus.devboard.local
192.168.1.40 alertmanager.devboard.local
192.168.1.40 vault.devboard.local
EOF'
```

### URLs accessibles

| Service | URL | Credentials |
|---------|-----|-------------|
| **DevBoard App** | http://dev.devboard.local | - |
| **Grafana** | http://grafana.devboard.local | admin / admin |
| **Prometheus** | http://prometheus.devboard.local | - |
| **Alertmanager** | http://alertmanager.devboard.local | - |
| **Vault** | http://vault.devboard.local | Token: root |

---

## 🔧 Kubeconfig

### Utiliser le kubeconfig local

```bash
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml

# Tester
kubectl get nodes
kubectl get pods -A
```

### Kubeconfig sur le serveur K3s

```bash
ssh root@192.168.1.40
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

---

## ⚠️ Sécurité - IMPORTANT

### ❌ Mode développement actuel

Les credentials actuels sont **UNIQUEMENT pour le développement** :

- ❌ Passwords simples (admin/admin, devboard-secret)
- ❌ Vault en mode dev (non persistant, unsealed auto)
- ❌ Pas de TLS/HTTPS
- ❌ Pas d'authentification sur Prometheus/Alertmanager
- ❌ Token Vault en clair (root)

### ✅ Pour la production

**À faire avant la mise en prod** :

1. **Changer tous les mots de passe**
   ```bash
   # Grafana : via UI ou kubectl
   kubectl exec -n monitoring prometheus-grafana-xxx -- \
     grafana-cli admin reset-admin-password <nouveau-mdp>
   
   # PostgreSQL : via SQL
   ALTER USER devboard WITH PASSWORD '<nouveau-mdp>';
   
   # Vault : générer de vrais tokens avec TTL
   ```

2. **Activer TLS/HTTPS** sur tous les Ingress
   ```bash
   # Installer cert-manager
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   
   # Configurer Let's Encrypt
   ```

3. **Vault en mode production**
   - Backend de stockage (etcd ou filesystem)
   - Unseal keys (5 keys, threshold 3)
   - Auto-unseal avec Cloud KMS

4. **Secrets management**
   - Utiliser External Secrets Operator
   - Rotation automatique des credentials
   - Vault Agent Injector pour les pods

5. **Network Policies**
   - Activer les NetworkPolicies en prod
   - Isoler les namespaces
   - Whitelister les communications

6. **Authentication**
   - Activer OAuth/OIDC sur Grafana
   - Basic Auth sur Prometheus/Alertmanager
   - RBAC strict sur Kubernetes

---

## 📋 Cheat Sheet

### Accès rapides

```bash
# Grafana
open http://grafana.devboard.local
# Login: admin / admin

# Vault
open http://vault.devboard.local
# Token: root

# DevBoard
open http://dev.devboard.local

# Prometheus
open http://prometheus.devboard.local

# SSH K3s server
ssh root@192.168.1.40

# Kubectl
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
kubectl get pods -A

# Logs backend
kubectl logs -f -n devboard-dev -l component=backend

# Shell dans Postgres
kubectl exec -it -n devboard-dev devboard-postgres-xxx -- psql -U devboard

# Vault CLI
export VAULT_ADDR=http://vault.devboard.local
export VAULT_TOKEN=root
vault kv list secret/devboard/
```

---

## 🆘 Mot de passe oublié ?

### Grafana

```bash
# Reset le mot de passe admin
kubectl exec -n monitoring prometheus-grafana-xxx -- \
  grafana-cli admin reset-admin-password newpassword

# Ou récupérer depuis le secret
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

### PostgreSQL

```bash
# Se connecter en root
kubectl exec -it -n devboard-dev devboard-postgres-xxx -- \
  psql -U postgres

# Changer le password
ALTER USER devboard WITH PASSWORD 'nouveau-password';
```

### Vault (mode dev)

En mode dev, le token est toujours `root`. En prod, utiliser les unseal keys.

---

## 📚 Voir aussi

- [SERVICES-ACCESS.md](SERVICES-ACCESS.md) - Guide complet d'accès aux services
- [SECURITY.md](SECURITY.md) - Documentation sécurité
- [MONITORING.md](MONITORING.md) - Accès Grafana/Prometheus
- [INFRASTRUCTURE.md](INFRASTRUCTURE.md) - SSH et Kubeconfig

---

**Dernière mise à jour** : 16 février 2026  
**⚠️ Rappel** : Ces credentials sont pour l'environnement de développement uniquement !
