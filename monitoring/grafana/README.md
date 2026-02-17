# Grafana Dashboards (DevBoard)

Dashboards versionnes pour Grafana:

- `dashboards/devboard-api-overview.json`
- `dashboards/devboard-k8s-workloads.json`
- `dashboards/devboard-logs-overview.json`
- `dashboards/devboard-capacity-greenit.json`

## Provisioning automatique (ArgoCD)

Les dashboards sont deployes automatiquement par l'application ArgoCD:

- `argocd/applications/monitoring-dashboards.yaml`
- manifests: `k8s/monitoring-dashboards/*.yaml`

Grafana les charge automatiquement via le sidecar dashboards (`grafana_dashboard: "1"`).

## Import manuel (optionnel)

1. Ouvrir Grafana (`http://grafana.devboard.local`)
2. Aller dans **Dashboards > New > Import**
3. Uploader un fichier JSON depuis `monitoring/grafana/dashboards/`
4. Mapper les datasources:
   - `DS_PROMETHEUS` -> datasource Prometheus
   - `DS_LOKI` -> datasource Loki

## Notes

- Les dashboards sont adaptes aux labels backend reels: `method`, `path`, `status`.
- Le namespace par defaut attendu est `default` (deployment actuel via ArgoCD).
- Les variables de dashboard permettent de changer facilement de namespace.
