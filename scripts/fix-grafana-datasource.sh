#!/bin/bash
# Corriger la configuration Grafana en supprimant les datasources en conflit

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🔧 Correction de la configuration Grafana"
echo "=========================================="

# D'abord, vérifier les configmaps de datasources
echo "ConfigMaps de datasources:"
kubectl get configmap -n monitoring -l grafana_datasource=1

echo ""
echo "En train de corriger..."

# Patcher la configmap pour retirer le isDefault de Prometheus
kubectl patch configmap -n monitoring prometheus-kube-prometheus-grafana-datasource \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/data/datasource.yaml",
      "value": "apiVersion: 1\ndatasources:\n- name: \"Prometheus\"\n  type: prometheus\n  uid: prometheus\n  url: http://prometheus-kube-prometheus-prometheus.monitoring:9090/\n  access: proxy\n  isDefault: false\n  jsonData:\n    httpMethod: POST\n    timeInterval: 30s\n- name: \"Alertmanager\"\n  type: alertmanager\n  uid: alertmanager\n  url: http://prometheus-kube-prometheus-alertmanager.monitoring:9093/\n  access: proxy\n  jsonData:\n    handleGrafanaManagedAlerts: false\n    implementation: prometheus\n"
    }
  ]'

echo ""
echo "✅ Configuration corrigée"
echo ""
echo "Redémarrage du pod Grafana..."
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

sleep 15

echo ""
echo "Vérification..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
