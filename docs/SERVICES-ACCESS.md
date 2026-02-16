# Services disponibles - DevBoard

## Infrastructure K3s
- **Cluster** : 3 nœuds (1 server + 2 agents)
- **IP K3s Server** : `192.168.1.40`
- **IP K3s Agent 1** : `192.168.1.41`
- **IP K3s Agent 2** : `192.168.1.42`

## Application DevBoard

### Accès web
- **URL** : http://dev.devboard.local
  - Frontend sur `/`
  - Backend API sur `/api/`
  
**Configuration locale requise** : Ajouter dans `/etc/hosts` :
```
192.168.1.40 dev.devboard.local
```

### Pods et services
```bash
kubectl get pods -n devboard-dev
# devboard-backend    → API REST (port 8080)
# devboard-frontend   → Interface React (port 80)
# devboard-postgres   → Base de données PostgreSQL (port 5432)
```

### Endpoints santé
- **Backend health** : `curl http://192.168.1.40/api/health`
- **Backend ready** : `curl http://192.168.1.40/api/ready`
- **Backend metrics** : `curl http://192.168.1.40/api/metrics`

## Monitoring (namespace: monitoring)

### Grafana
- **Service** : `prometheus-grafana.monitoring.svc.cluster.local`
- **Port interne** : 80
- **Accès** : Port-forward depuis ta machine locale
  ```bash
  export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
  ```
- **URL locale** : http://localhost:3000
- **Credentials** :
  - Username : `admin`
  - Password : `admin` (ou récupérer via : `kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d`)

### Prometheus
- **Service** : `prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local`
- **Port interne** : 9090
- **Accès** :
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
  ```
- **URL locale** : http://localhost:9090

### Alertmanager
- **Service** : `prometheus-kube-prometheus-alertmanager.monitoring.svc.cluster.local`
- **Port interne** : 9093
- **Accès** :
  ```bash
  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
  ```
- **URL locale** : http://localhost:9093

### Loki (Logs)
- **Service** : `loki.monitoring.svc.cluster.local`
- **Port interne** : 3100
- **Configuration Grafana** : Ajouter datasource Loki avec URL `http://loki.monitoring.svc.cluster.local:3100`

## Sécurité (namespace: security)

### Vault
- **Service** : `vault.security.svc.cluster.local`
- **Port interne** : 8200
- **Mode** : dev (non-production)
- **Token root** : `root`
- **Accès** :
  ```bash
  kubectl port-forward -n security svc/vault 8200:8200
  ```
- **URL locale** : http://localhost:8200
- **CLI Vault** :
  ```bash
  export VAULT_ADDR=http://localhost:8200
  export VAULT_TOKEN=root
  vault kv list secret/devboard/
  ```

### Secrets stockés dans Vault
- `secret/devboard/db` → Credentials PostgreSQL
- `secret/devboard/jwt` → Secret JWT pour l'authentification

## Accès SSH aux nœuds K3s

```bash
# Server
ssh root@192.168.1.40

# Agents
ssh root@192.168.1.41
ssh root@192.168.1.42
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
ssh root@192.168.1.40
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
