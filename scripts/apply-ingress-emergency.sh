#!/bin/bash
# Script d'urgence : appliquer manuellement les ingress manquants
# À exécuter depuis le master si ArgoCD ne peut pas les appliquer

set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🔧 Application manuelle des ingress"
echo "===================================="
echo ""

# Créer les namespaces s'ils n'existent pas
echo "📦 Création des namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespaces créés"
echo ""

# Appliquer les ingress directement
echo "🔗 Application des ingress..."

# ArgoCD
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: traefik
  rules:
    - host: argocd.devboard.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF
echo "✅ ArgoCD Ingress appliqué"

# Prometheus
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - host: prometheus.devboard.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-stack-kube-prom-prometheus
                port:
                  number: 9090
EOF
echo "✅ Prometheus Ingress appliqué"

# Grafana (via service monitoring-stack-grafana)
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: monitoring
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - host: grafana.devboard.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: monitoring-stack-grafana
                port:
                  number: 80
EOF
echo "✅ Grafana Ingress appliqué"

# Vault
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault-ingress
  namespace: security
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: vault.devboard.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault
                port:
                  number: 8200
EOF
echo "✅ Vault Ingress appliqué"

echo ""
echo "🎯 Ingress appliqués avec succès!"
echo ""
echo "Vérification:"
kubectl get ingress -A | grep -E "argocd|prometheus|grafana|vault"
echo ""
echo "Attendez 30 secondes puis testez l'accès."
