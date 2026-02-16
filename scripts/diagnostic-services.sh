#!/bin/bash
# Script de diagnostic complet des services K3s DevBoard
# À exécuter depuis le master K3s (192.168.1.40)

set -e

echo "==============================================="
echo "DIAGNOSTIC COMPLET - SERVICES DEVBOARD"
echo "==============================================="
echo ""

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# 1. VÉRIFIER TRAEFIK
echo "📌 1. VÉRIFICATION DE TRAEFIK"
echo "=================================="
kubectl get pod -n kube-system -l app.kubernetes.io/name=traefik 2>/dev/null || echo "⚠️  Traefik non trouvé dans kube-system"
kubectl get svc -n kube-system -l app.kubernetes.io/name=traefik 2>/dev/null || echo "⚠️  Service Traefik non trouvé"
echo ""

# 2. VÉRIFIER LES INGRESS
echo "📌 2. VÉRIFICATION DES INGRESS CONFIGURÉS"
echo "=================================="
echo "ArgoCD Ingress:"
kubectl get ingress -n argocd 2>/dev/null | grep -E "NAME|argocd" || echo "⚠️  Ingress ArgoCD manquant"
echo ""
echo "Monitoring Ingress:"
kubectl get ingress -n monitoring 2>/dev/null | grep -E "NAME|prometheus|grafana|alertmanager" || echo "⚠️  Ingress Monitoring manquant"
echo ""
echo "Vault Ingress:"
kubectl get ingress -n security 2>/dev/null | grep -E "NAME|vault" || echo "⚠️  Ingress Vault manquant"
echo ""

# 3. VÉRIFIER LES SERVICES
echo "📌 3. VÉRIFICATION DES SERVICES"
echo "=================================="
echo "ArgoCD Service:"
kubectl get svc -n argocd 2>/dev/null || echo "⚠️  Namespace argocd inaccessible"
echo ""
echo "Monitoring Services:"
kubectl get svc -n monitoring 2>/dev/null || echo "⚠️  Namespace monitoring inaccessible"
echo ""
echo "Vault Service:"
kubectl get svc -n security 2>/dev/null || echo "⚠️  Namespace security inaccessible"
echo ""

# 4. VÉRIFIER LES PODS
echo "📌 4. VÉRIFICATION DES PODS"
echo "=================================="
echo "ArgoCD Pods:"
kubectl get pods -n argocd 2>/dev/null || echo "⚠️  Namespace argocd inaccessible"
echo ""
echo "Monitoring Pods:"
kubectl get pods -n monitoring 2>/dev/null || echo "⚠️  Namespace monitoring inaccessible"
echo ""
echo "Vault Pods:"
kubectl get pods -n security 2>/dev/null || echo "⚠️  Namespace security inaccessible"
echo ""

# 5. VÉRIFIER LES APPLICATIONS ARGOCD
echo "📌 5. VÉRIFICATION DES APPLICATIONS ARGOCD"
echo "=================================="
kubectl get applications -n argocd -o wide 2>/dev/null || echo "⚠️  ArgoCD applications manquantes"
echo ""

# 6. VÉRIFIER LES POLITIQUES RÉSEAU
echo "📌 6. VÉRIFICATION DES NETWORK POLICIES"
echo "=================================="
echo "DevBoard network policies:"
kubectl get networkpolicies -n devboard 2>/dev/null || echo "⚠️  Pas de network policies"
echo ""
echo "Monitoring network policies:"
kubectl get networkpolicies -n monitoring 2>/dev/null || echo "⚠️  Pas de network policies"
echo ""
echo "ArgoCD network policies:"
kubectl get networkpolicies -n argocd 2>/dev/null || echo "⚠️  Pas de network policies"
echo ""
echo "Security network policies:"
kubectl get networkpolicies -n security 2>/dev/null || echo "⚠️  Pas de network policies"
echo ""

# 7. VÉRIFIER LES ENDPOINTS
echo "📌 7. VÉRIFICATION DES ENDPOINTS"
echo "=================================="
echo "ArgoCD Server Endpoints:"
kubectl get endpoints -n argocd argocd-server 2>/dev/null || echo "⚠️  Endpoints argocd-server manquants"
echo ""
echo "Prometheus Endpoints:"
kubectl get endpoints -n monitoring monitoring-stack-kube-prom-prometheus 2>/dev/null || echo "⚠️  Endpoints Prometheus manquants"
echo ""
echo "Vault Endpoints:"
kubectl get endpoints -n security vault 2>/dev/null || echo "⚠️  Endpoints Vault manquants"
echo ""

# 8. VÉRIFIER LES LOGS TRAEFIK
echo "📌 8. LOGS RÉCENTS TRAEFIK"
echo "=================================="
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=20 2>/dev/null | tail -15 || echo "⚠️  Impossible de lire les logs Traefik"
echo ""

# 9. VÉRIFIER LA RÉSOLUTION DNS
echo "📌 9. RÉSOLUTION DNS DES SERVICES"
echo "=================================="
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup argocd-server.argocd.svc.cluster.local 2>/dev/null || echo "⚠️  Pod debug non disponible"
echo ""

echo "==============================================="
echo "FIN DU DIAGNOSTIC"
echo "==============================================="
