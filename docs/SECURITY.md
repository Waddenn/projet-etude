# Sécurité - Documentation

## Vue d'ensemble

La sécurité du projet DevBoard repose sur plusieurs couches :
- **Vault** : Gestion centralisée des secrets
- **Trivy** : Scan de vulnérabilités des images Docker
- **RBAC** : Contrôle d'accès basé sur les rôles (Kubernetes)
- **NetworkPolicies** : Segmentation réseau
- **Secrets Kubernetes** : Stockage sécurisé des credentials

---

## 1. HashiCorp Vault

### 🎯 Rôle
Vault centralise et sécurise les secrets (credentials DB, JWT tokens, API keys).

### 📍 Accès
- **URL** : http://vault.devboard.local
- **Token root** : `root` (⚠️ mode dev uniquement !)
- **Namespace** : `security`
- **Service** : `vault:8200`

### ⚠️ Mode DEV (actuel)

Vault est actuellement en **mode développement** :
- ✅ Unsealed automatiquement
- ✅ Pas de stockage persistant (in-memory)
- ❌ **NON adapté pour la production !**
- ✅ Parfait pour le développement et les démos

**Pour la production** : Utiliser Vault en mode production avec un backend de stockage (etcd, Consul, ou filesystem) et plusieurs sceaux (unseal keys).

### 🔑 Secrets stockés

#### Database credentials
```bash
vault kv get secret/devboard/db

# Résultat :
# Key         Value
# ---         -----
# username    devboard
# password    <voir .env.secrets>
# host        postgres
# port        5432
# database    devboard
```

#### JWT secret
```bash
vault kv get secret/devboard/jwt

# Résultat :
# Key       Value
# ---       -----
# secret    changeme-jwt-secret-minimum-32-chars
```

### 📝 Policies

Policy `devboard` (lecture seule sur les secrets devboard) :

```hcl
# /tmp/devboard-policy.hcl
path "secret/data/devboard/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/devboard/*" {
  capabilities = ["read", "list"]
}
```

Appliquée avec :
```bash
vault policy write devboard /tmp/devboard-policy.hcl
```

### 🔐 Kubernetes Auth

Vault est configuré pour l'authentification Kubernetes.

Les pods peuvent s'authentifier avec leur **ServiceAccount** :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: devboard
  namespace: devboard-dev
```

**Configuration** :
```bash
vault write auth/kubernetes/role/devboard \
  bound_service_account_names=devboard \
  bound_service_account_namespaces=devboard-dev,devboard-staging,devboard-prod \
  policies=devboard \
  ttl=1h
```

### 🚀 Commandes Vault

```bash
# Se connecter
export VAULT_ADDR=http://vault.devboard.local
export VAULT_TOKEN=root

# Lister les secrets
vault kv list secret/devboard/

# Lire un secret
vault kv get secret/devboard/db

# Écrire un secret
vault kv put secret/devboard/api-key key=xxx

# Supprimer un secret
vault kv delete secret/devboard/api-key

# Lister les policies
vault policy list

# Voir une policy
vault policy read devboard

# Auth methods actifs
vault auth list

# Status de Vault
vault status
```

### 🔧 Intégration avec l'application

**Option 1 : Via Secret Kubernetes** (approche actuelle)

Les secrets Vault sont copiés manuellement dans un Secret K8s :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: devboard-secrets
stringData:
  db-username: devboard
  db-password: <voir .env.secrets>  # généré par make generate-secrets
  database-url: postgres://devboard:<voir .env.secrets>@postgres:5432/devboard
```

**Option 2 : Vault Agent Injector** (meilleure pratique)

Utiliser le sidecar Vault Agent pour injecter automatiquement les secrets :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devboard-backend
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "devboard"
        vault.hashicorp.com/agent-inject-secret-db: "secret/data/devboard/db"
    spec:
      serviceAccountName: devboard
      containers:
        - name: backend
          # Les secrets seront montés dans /vault/secrets/db
```

---

## 2. Trivy - Scan de vulnérabilités

### 🎯 Rôle
Scanner de sécurité pour détecter les vulnérabilités dans les images Docker, manifests Kubernetes, et dépendances.

### 📁 Configuration
`security/trivy/trivy-config.yml`

```yaml
# Sévérités à rapporter
severity:
  - CRITICAL
  - HIGH
  - MEDIUM

# Types de vulnérabilités
vuln-type:
  - os        # Packages système
  - library   # Dépendances applicatives

# Ignorer les vulnérabilités non fixées
ignore-unfixed: true
```

### 🔍 Scanner une image

```bash
# Scanner l'image backend
trivy image devboard-backend:latest

# Scanner avec output JSON
trivy image -f json -o results.json devboard-backend:latest

# Scanner seulement les vulns CRITICAL/HIGH
trivy image --severity CRITICAL,HIGH devboard-backend:latest

# Scanner une image distante
trivy image ghcr.io/votre-groupe/devboard/backend:latest
```

### 🛡️ Scanner les manifests Kubernetes

```bash
# Scanner les manifests
trivy config helm/devboard/

# Scanner un fichier spécifique
trivy config k8s/base/backend.yaml
```

### 📊 Exemple de sortie

```
devboard-backend:latest (debian 12.0)
=====================================
Total: 5 (CRITICAL: 1, HIGH: 2, MEDIUM: 2)

┌───────────────┬────────────────┬──────────┬───────────────────┬───────────────┬────────────────────────────────────┐
│    Library    │ Vulnerability  │ Severity │ Installed Version │ Fixed Version │              Title                 │
├───────────────┼────────────────┼──────────┼───────────────────┼───────────────┼────────────────────────────────────┤
│ openssl       │ CVE-2024-0727  │ CRITICAL │ 3.0.11-1          │ 3.0.13-1      │ openssl: denial of service via...  │
│ curl          │ CVE-2023-46218 │ HIGH     │ 8.4.0-2           │ 8.5.0-1       │ curl: cookie injection            │
│ ...           │ ...            │ ...      │ ...               │ ...           │ ...                                │
└───────────────┴────────────────┴──────────┴───────────────────┴───────────────┴────────────────────────────────────┘
```

### 🔄 Intégration CI/CD

Dans `.github/workflows/ci.yml` :

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: devboard-backend:latest
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'

- name: Upload Trivy results to GitHub Security
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

### ✅ Bonnes pratiques

- ✅ Utiliser des images de base minimales (`alpine`, `scratch`)
- ✅ Multi-stage builds pour réduire la surface d'attaque
- ✅ Scanner les images avant chaque déploiement
- ✅ Bloquer le déploiement si CRITICAL vulns
- ✅ Mettre à jour régulièrement les images de base

---

## 3. RBAC Kubernetes

### 🎯 Rôle
Contrôler qui peut faire quoi dans le cluster Kubernetes.

### 📁 Fichiers
`security/rbac/`

### 📋 Roles définis

#### Role : `developer` (namespace devboard-dev)

Permissions :
- ✅ Lire pods, services, deployments, logs
- ✅ Créer/modifier/supprimer ses propres ressources
- ❌ Pas d'accès aux secrets
- ❌ Pas d'accès aux autres namespaces

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: devboard-dev
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "services", "deployments", "jobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
```

#### Role : `readonly-prod` (namespace devboard-prod)

Permissions :
- ✅ Lire toutes les ressources
- ❌ Aucune modification

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: readonly-prod
  namespace: devboard-prod
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
```

### 🔗 RoleBinding

Lier un user/group au role :

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: devboard-dev
subjects:
  - kind: User
    name: john.doe@example.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

### 🧪 Tester les permissions

```bash
# Vérifier si un user peut faire une action
kubectl auth can-i get pods --namespace devboard-dev --as john.doe@example.com

# Lister toutes les permissions d'un user
kubectl auth can-i --list --namespace devboard-dev --as john.doe@example.com
```

---

## 4. Network Policies

### 🎯 Rôle
Segmenter le réseau entre les pods pour limiter les communications.

### 📋 Policies définies

#### Policy : Backend → Postgres uniquement

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: devboard-dev
spec:
  podSelector:
    matchLabels:
      component: backend
  policyTypes:
    - Egress
  egress:
    # Autoriser vers Postgres
    - to:
        - podSelector:
            matchLabels:
              component: postgres
      ports:
        - protocol: TCP
          port: 5432
    # Autoriser DNS
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
```

#### Policy : Isoler le namespace monitoring

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    # Autoriser seulement depuis l'ingress
    - from:
        - namespaceSelector:
            matchLabels:
              name: kube-system
```

### 🧪 Tester les Network Policies

```bash
# Tester la connexion backend → postgres (DOIT marcher)
kubectl exec -n devboard-dev <backend-pod> -- nc -zv postgres 5432

# Tester la connexion backend → frontend (DOIT échouer si policy active)
kubectl exec -n devboard-dev <backend-pod> -- nc -zv devboard-frontend 80
```

---

## 5. Secrets Kubernetes

### 📦 Secret actuel

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: devboard-secrets
  namespace: devboard-dev
type: Opaque
stringData:
  db-username: devboard
  db-password: <voir .env.secrets>  # généré par make generate-secrets
  database-url: postgres://devboard:<voir .env.secrets>@postgres:5432/devboard
  jwt-secret: <voir .env.secrets>  # généré par make generate-secrets
```

### 🔒 Bonnes pratiques

- ✅ Utiliser `stringData` (encode automatiquement en base64)
- ✅ Ne jamais commiter les secrets dans Git
- ✅ Utiliser Vault ou External Secrets Operator en production
- ✅ Rotation régulière des secrets
- ✅ Limiter l'accès via RBAC

### 📝 Créer un secret

```bash
# Depuis un fichier
kubectl create secret generic db-secret \
  --from-file=username.txt \
  --from-file=password.txt \
  -n devboard-dev

# Depuis des literals
kubectl create secret generic db-secret \
  --from-literal=username=devboard \
  --from-literal=password=secret \
  -n devboard-dev

# Depuis un manifest
kubectl apply -f secret.yaml
```

### 🔍 Lire un secret

```bash
# Voir le secret (base64 encodé)
kubectl get secret devboard-secrets -n devboard-dev -o yaml

# Décoder un secret
kubectl get secret devboard-secrets -n devboard-dev \
  -o jsonpath='{.data.db-password}' | base64 -d
```

---

## 6. Audit et Conformité

### 📊 Checklist sécurité

- [x] Images scannées avec Trivy
- [x] Secrets stockés dans Vault
- [x] RBAC configuré
- [ ] Network Policies activées en prod
- [ ] TLS sur Ingress (HTTPS)
- [ ] Pod Security Standards (PSS)
- [ ] Scan régulier des vulnérabilités
- [ ] Logs d'audit Kubernetes activés

### 🔐 Renforcer la sécurité (TODO)

1. **TLS/HTTPS** : Activer TLS sur l'Ingress avec cert-manager
2. **Pod Security** : Appliquer des Pod Security Standards
3. **Image signing** : Signer les images avec Cosign
4. **Vault production** : Migrer vers Vault production avec HA
5. **Rotate secrets** : Automatiser la rotation des credentials
6. **OPA/Gatekeeper** : Policies de validation des manifests

---

## 📚 Références

- [HashiCorp Vault](https://www.vaultproject.io/docs)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
