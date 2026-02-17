# Monitoring et Observabilité - Documentation

## Vue d'ensemble

La stack de monitoring DevBoard utilise :
- **Prometheus** : Collecte et stockage des métriques
- **Grafana** : Visualisation et dashboards
- **Loki** : Agrégation de logs
- **Promtail** : Agent de collecte de logs
- **Alertmanager** : Gestion des alertes

---

## Architecture Monitoring

```
┌──────────────────────────────────────────────────────┐
│                    Grafana                            │
│             http://grafana.devboard.local             │
│  ┌─────────────────────────────────────────────┐    │
│  │  Dashboards                                 │    │
│  │  - Application (DevBoard)                   │    │
│  │  - Infrastructure (K8s)                     │    │
│  │  - Green IT (consommation)                  │    │
│  │  - Sécurité                                 │    │
│  └─────────────────────────────────────────────┘    │
└───────┬────────────────────┬─────────────────────────┘
        │                    │
        │ Query              │ Query
        │                    │
┌───────▼──────────┐  ┌──────▼───────────┐
│   Prometheus     │  │      Loki        │
│  (Métriques)     │  │     (Logs)       │
│                  │  │                  │
│  - Scraping      │  │  - Log storage   │
│  - Storage TSDB  │  │  - Indexation    │
│  - PromQL        │  │  - LogQL         │
└───────▲──────────┘  └──────▲───────────┘
        │                    │
        │ /metrics           │ Push logs
        │                    │
┌───────┴──────────┐  ┌──────┴───────────┐
│   Exporters      │  │    Promtail      │
│                  │  │                  │
│  - Node exporter │  │  - Node 1        │
│  - Kube metrics  │  │  - Node 2        │
│  - App /metrics  │  │  - Node 3        │
└──────────────────┘  └──────────────────┘
```

---

## 1. Prometheus

### 🎯 Rôle
Collecte, stocke et expose les métriques de tous les composants du système.

### 📍 Accès
- **URL** : http://prometheus.devboard.local
- **Namespace** : `monitoring`
- **Service** : `prometheus-kube-prometheus-prometheus:9090`

### 📊 Sources de métriques

| Source                | Type              | Endpoint                  | Description                    |
|-----------------------|-------------------|---------------------------|--------------------------------|
| **DevBoard Backend**  | Application       | `:8080/metrics`       | Métriques app (requêtes, latence) |
| **Node Exporters**    | Infrastructure    | `:9100/metrics`           | CPU, RAM, disk des nœuds K3s   |
| **Kube State Metrics**| Kubernetes        | `:8080/metrics`           | État des ressources K8s        |
| **cAdvisor**          | Containers        | `:4194/metrics`           | Métriques des containers       |
| **Traefik**           | Ingress           | `:9100/metrics`           | Trafic HTTP, latence           |

### 🔧 Configuration du scraping

Prometheus scrape automatiquement tous les services qui ont :
- Une annotation `prometheus.io/scrape: "true"`
- Un label `app.kubernetes.io/name: <app>`

Exemple de ServiceMonitor (déjà configuré via kube-prometheus-stack) :

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: devboard-backend
spec:
  selector:
    matchLabels:
      app: devboard
      component: backend
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### 📈 Métriques clés exposées par DevBoard

```prometheus
# Requêtes HTTP totales
http_requests_total{method="GET",path="/api/projects",status="200"} 1523

# Durée des requêtes (histogramme)
http_request_duration_seconds_bucket{method="GET",path="/api/projects",le="0.1"} 1420
http_request_duration_seconds_bucket{method="GET",path="/api/projects",le="0.5"} 1500
http_request_duration_seconds_sum{method="GET",path="/api/projects"} 145.2
http_request_duration_seconds_count{method="GET",path="/api/projects"} 1523

# Requêtes en cours
http_requests_in_progress{method="GET",path="/api/projects"} 3

# Métriques Go
go_goroutines 15
go_memstats_alloc_bytes 2.5e+06
go_memstats_heap_inuse_bytes 4.2e+06
```

### 🔍 Requêtes PromQL utiles

```promql
# Taux de requêtes par seconde
rate(http_requests_total[5m])

# Latence P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Taux d'erreur (4xx, 5xx)
sum(rate(http_requests_total{status=~"4..|5.."}[5m])) / sum(rate(http_requests_total[5m]))

# CPU usage des pods
sum(rate(container_cpu_usage_seconds_total{namespace="default"}[5m])) by (pod)

# Memory usage des pods
sum(container_memory_working_set_bytes{namespace="default"}) by (pod)

# Pods non-ready
count(kube_pod_status_ready{namespace="default",condition="false"})
```

### 📝 Fichier de configuration

Les règles d'alerting custom sont dans `monitoring/prometheus/custom-rules.yml` :

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: devboard-alerts
  namespace: monitoring
spec:
  groups:
    - name: devboard
      interval: 30s
      rules:
        # Alert: Taux d'erreur élevé
        - alert: HighErrorRate
          expr: |
            (sum(rate(http_requests_total{status=~"5.."}[5m])) by (path) 
            / sum(rate(http_requests_total[5m])) by (path)) > 0.05
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Taux d'erreur élevé sur {{ $labels.path }}"
            description: "Le taux d'erreur est de {{ $value | humanizePercentage }}"

        # Alert: Latence élevée
        - alert: HighLatency
          expr: |
            histogram_quantile(0.95, 
              rate(http_request_duration_seconds_bucket[5m])
            ) > 1.0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Latence P95 élevée"
            description: "La latence P95 est de {{ $value }}s"

        # Alert: Backend down
        - alert: BackendDown
          expr: |
            absent(up{job="devboard-backend"}) or 
            up{job="devboard-backend"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Backend DevBoard est down"
            description: "Le backend ne répond plus depuis 1 minute"
```

### 🚀 Commandes utiles

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Recharger la configuration
kubectl rollout restart statefulset prometheus-prometheus-kube-prometheus-prometheus -n monitoring

# Vérifier les targets
curl http://prometheus.devboard.local/api/v1/targets

# Requête PromQL via API
curl -G 'http://prometheus.devboard.local/api/v1/query' \
  --data-urlencode 'query=up'
```

---

## 2. Grafana

### 🎯 Rôle
Plateforme de visualisation pour créer des dashboards interactifs.

### 📍 Accès
- **URL** : http://grafana.devboard.local
- **Credentials** : `admin` / `admin`
- **Namespace** : `monitoring`
- **Service** : `prometheus-grafana:80`

### 📊 Datasources configurées

1. **Prometheus** (par défaut)
   - URL : `http://prometheus-kube-prometheus-prometheus:9090`
   - Type : Time Series
   - Utilisé pour : Métriques

2. **Loki** (préconfiguré)
   - URL : `http://loki-stack:3100`
   - Type : Logs
   - Utilisé pour : Logs applicatifs

### 📈 Dashboards à créer

#### Dashboard 1 : Application DevBoard

**Panels** :
- Taux de requêtes (QPS)
- Latence P50, P95, P99
- Taux d'erreur (4xx, 5xx)
- Requêtes par endpoint
- Top endpoints les plus lents
- Nombre de goroutines
- Memory usage

**Exemple de requête PromQL** :
```promql
# QPS
sum(rate(http_requests_total{namespace="default"}[5m]))

# Latence P95
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{namespace="default"}[5m])) by (le)
)

# Erreurs 5xx
sum(rate(http_requests_total{status=~"5..",namespace="default"}[5m]))
```

#### Dashboard 2 : Infrastructure Kubernetes

**Panels** :
- CPU usage par nœud
- Memory usage par nœud
- Disk I/O
- Network traffic
- Pods par namespace
- Pod restarts
- Status des nœuds

**Requêtes PromQL** :
```promql
# CPU par nœud
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory par nœud
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Pods running
sum(kube_pod_status_phase{phase="Running"}) by (namespace)
```

#### Dashboard 3 : Green IT

**Panels** :
- Consommation CPU moyenne
- Consommation RAM moyenne
- Taille des images Docker
- Nombre de réplicas actifs
- Taux d'utilisation des ressources
- Comparaison avant/après optimisations

**Requêtes PromQL** :
```promql
# CPU usage moyen de l'app
avg(rate(container_cpu_usage_seconds_total{namespace="default"}[5m]))

# Memory usage de l'app
sum(container_memory_working_set_bytes{namespace="default"})

# Nombre de pods
count(kube_pod_info{namespace="default"})
```

#### Dashboard 4 : Sécurité

**Panels** :
- Scans Trivy (nombre de vulnérabilités)
- Pods sans resource limits
- Images avec CVEs critiques
- Accès Vault (nombre de requêtes)
- Failed login attempts (si auth activée)

### 🎨 Créer un dashboard

1. Aller sur http://grafana.devboard.local
2. Login : `<voir .env.secrets>`
3. Dashboards → New → New Dashboard
4. Add visualization
5. Sélectionner datasource : Prometheus
6. Écrire la requête PromQL
7. Configurer le panel (titre, unité, légende)
8. Sauvegarder

### 📤 Exporter/Importer un dashboard

```bash
# Exporter un dashboard (JSON)
# Dashboards → Settings → JSON Model → Copier

# Importer un dashboard
# Dashboards → New → Import → Coller le JSON
```

### 🔔 Configurer des alertes dans Grafana

1. Dans un dashboard panel → Alert
2. Définir la condition (ex: `value > 80`)
3. Choisir le canal de notification (email, Slack, webhook)
4. Sauvegarder

---

## 3. Loki (Logs)

### 🎯 Rôle
Agrégateur de logs inspiré de Prometheus (labels, pas d'indexation full-text).

### 📍 Accès
- **Pas d'UI web directe** (utiliser Grafana Explore)
- **Namespace** : `monitoring`
- **Service** : `loki:3100`
- **API** : `http://loki.monitoring.svc.cluster.local:3100`

### 📝 Architecture Loki

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Promtail (1) │  │ Promtail (2) │  │ Promtail (3) │
│  Node 1      │  │  Node 2      │  │  Node 3      │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       │ Push logs       │ Push logs       │ Push logs
       └─────────────────┼─────────────────┘
                         │
                   ┌─────▼─────┐
                   │   Loki    │
                   │  Server   │
                   │           │
                   │ - Ingest  │
                   │ - Storage │
                   │ - Query   │
                   └───────────┘
```

### 📊 Promtail (agent de collecte)

Promtail tourne en **DaemonSet** (1 pod par nœud) et collecte les logs de :
- Tous les containers (`/var/log/pods/`)
- System logs (`/var/log/`)

Configuration automatique via labels Kubernetes.

### 🔍 Requêtes LogQL (dans Grafana Explore)

```logql
# Tous les logs du namespace default
{namespace="default"}

# Logs du backend uniquement
{namespace="default", container="backend"}

# Logs avec le mot "error"
{namespace="default"} |= "error"

# Logs avec regex
{namespace="default"} |~ "error|failed|panic"

# Compter les erreurs par minute
sum by (pod) (rate({namespace="default"} |= "error" [1m]))

# Logs des dernières 24h
{namespace="default"} [24h]
```

### 🚀 Utiliser Loki dans Grafana

1. Aller sur http://grafana.devboard.local
2. Explore (icône boussole dans la sidebar)
3. Sélectionner datasource : Loki
4. Écrire une requête LogQL
5. Voir les logs en temps réel

### 📦 Ajouter Loki comme datasource dans Grafana

```bash
# Via l'UI Grafana
Configuration → Data Sources → Add data source → Loki
URL: http://loki.monitoring.svc.cluster.local:3100

# Ou via API
curl -X POST http://grafana.devboard.local/api/datasources \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://loki.monitoring.svc.cluster.local:3100",
    "access": "proxy",
    "isDefault": false
  }'
```

---

## 4. Alertmanager

### 🎯 Rôle
Gère les alertes de Prometheus : déduplication, groupement, routage, silencing.

### 📍 Accès
- **URL** : http://alertmanager.devboard.local
- **Namespace** : `monitoring`
- **Service** : `prometheus-kube-prometheus-alertmanager:9093`

### 🔔 Configuration des notifications

Alertmanager peut envoyer des notifications vers :
- Email
- Slack
- PagerDuty
- Webhook
- Microsoft Teams
- Discord

Exemple de configuration (à ajouter via Helm values) :

```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'
            channel: '#devboard-alerts'
            title: 'DevBoard Alert'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    
    route:
      receiver: 'slack-notifications'
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
```

### 📊 Visualiser les alertes

- **Alertes actives** : http://alertmanager.devboard.local/#/alerts
- **Silenced** : http://alertmanager.devboard.local/#/silences

### 🔇 Silence une alerte

```bash
# Via l'UI
# Alertmanager → Alerts → Silence

# Via API
curl -X POST http://alertmanager.devboard.local/api/v2/silences \
  -H 'Content-Type: application/json' \
  -d '{
    "matchers": [{"name": "alertname", "value": "HighErrorRate"}],
    "startsAt": "2026-02-16T12:00:00Z",
    "endsAt": "2026-02-16T14:00:00Z",
    "createdBy": "admin",
    "comment": "Maintenance en cours"
  }'
```

---

## 5. Commandes utiles

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Logs de Loki
kubectl logs -n monitoring loki-0

# Logs de Promtail (sur un nœud spécifique)
kubectl logs -n monitoring promtail-<pod-id>

# Restart Grafana
kubectl rollout restart deployment prometheus-grafana -n monitoring

# Test requête Prometheus
curl 'http://prometheus.devboard.local/api/v1/query?query=up'

# Test Loki
curl 'http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/labels'
```

---

## 6. Métriques Green IT

Pour le projet, mesurer et afficher :

### Avant optimisation
- Taille image backend : ~XXX Mo
- Taille image frontend : ~XXX Mo
- CPU moyen : XXX millicores
- RAM moyenne : XXX Mi

### Après optimisation
- Taille image backend : **~4 Mo** ✅
- Taille image frontend : **~25 Mo** ✅
- CPU moyen : À mesurer
- RAM moyenne : À mesurer

**Dashboard Grafana** : Créer des panels pour comparer les métriques avant/après.

---

## 📚 Références

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [LogQL Guide](https://grafana.com/docs/loki/latest/logql/)
