#!/bin/bash
# Test de connectivité aux ingress existants et aux services

set +e  # Ne pas quitter si une commande échoue

export KUBECONFIG=${KUBECONFIG:-/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml}

echo "=================================================="
echo "TEST DE CONNECTIVITÉ AUX SERVICES"
echo "=================================================="
echo ""

# Configuration requise
HOSTS_ENTRY="192.168.1.40 argocd.devboard.local prometheus.devboard.local grafana.devboard.local vault.devboard.local"

# Vérifier que le kubeconfig existe
if [ ! -f "$KUBECONFIG" ]; then
    echo "❌ Kubeconfig non trouvé: $KUBECONFIG"
    exit 1
fi

echo "✅ Kubeconfig: $KUBECONFIG"
echo ""

# Test 1: Services accessibles directement par IP
echo "📌 TEST 1 - Accès direct par IP (192.168.1.40)"
echo "=================================================="

# Traefik devrait répondre sur le port 80
echo "Prometheus (port 80 via Traefik):"
timeout 5 curl -s -H "Host: prometheus.devboard.local" http://192.168.1.40 > /dev/null && echo "✅ Connecté" || echo "❌ Non connecté"

echo ""
echo "Vault (port 80 via Traefik):"
timeout 5 curl -s -H "Host: vault.devboard.local" http://192.168.1.40 > /dev/null && echo "✅ Connecté" || echo "❌ Non connecté"

echo ""
echo "Grafana (port 80 via Traefik):"
timeout 5 curl -s -H "Host: grafana.devboard.local" http://192.168.1.40 > /dev/null && echo "✅ Connecté" || echo "❌ Non connecté"

echo ""
echo "ArgoCD (port 80 via Traefik):"
timeout 5 curl -s -H "Host: argocd.devboard.local" http://192.168.1.40 > /dev/null && echo "✅ Connecté" || echo "❌ Non connecté"

echo ""
echo ""

# Test 2: Vérifier les ingress définis
echo "📌 TEST 2 - Inspection des Ingress"
echo "=================================================="

echo "Ingress dans argocd:"
kubectl get ingress -n argocd 2>/dev/null | tail -5

echo ""
echo "Ingress dans monitoring:"
kubectl get ingress -n monitoring 2>/dev/null | tail -5

echo ""
echo "Ingress dans security:"
kubectl get ingress -n security 2>/dev/null | tail -5

echo ""
echo ""

# Test 3: Vérifier les endpoints (pods prêts)
echo "📌 TEST 3 - Endpoints disponibles"
echo "=================================================="

echo "ArgoCD Server:"
kubectl get endpoints -n argocd argocd-server 2>/dev/null || echo "⚠️  Endpoint manquant"

echo ""
echo "Prometheus:"
kubectl get endpoints -n monitoring monitoring-stack-kube-prom-prometheus 2>/dev/null || echo "⚠️  Endpoint manquant"

echo ""
echo "Grafana:"
kubectl get endpoints -n monitoring monitoring-stack-grafana 2>/dev/null || echo "⚠️  Endpoint manquant"

echo ""
echo "Vault:"
kubectl get endpoints -n security vault 2>/dev/null || echo "⚠️  Endpoint manquant"

echo ""
echo ""

# Test 4: Statut des pods
echo "📌 TEST 4 - Statut des Pods"
echo "=================================================="

echo "ArgoCD:"
kubectl get pods -n argocd 2>/dev/null || echo "⚠️  Namespace argocd non accessible"

echo ""
echo "Monitoring:"
kubectl get pods -n monitoring 2>/dev/null | head -10 || echo "⚠️  Namespace monitoring non accessible"

echo ""
echo "Security:"
kubectl get pods -n security 2>/dev/null || echo "⚠️  Namespace security non accessible"

echo ""
echo ""

# Test 5: ArgoCD Applications Status
echo "📌 TEST 5 - Statut des Applications ArgoCD"
echo "=================================================="

kubectl get applications -n argocd -o wide 2>/dev/null || echo "❌ Impossible de lire les applications"

echo ""
echo ""

# Test 6: Instructions pour tester depuis le navigateur
echo "📌 VÉRIFICATION MANUELLE DEPUIS TON NAVIGATEUR"
echo "=================================================="
echo ""
echo "Ajoute dans ton /etc/hosts:"
echo "  $HOSTS_ENTRY"
echo ""
echo "Puis accède à:"
echo "  • ArgoCD: http://argocd.devboard.local (login: admin)"
echo "  • Prometheus: http://prometheus.devboard.local"
echo "  • Grafana: http://grafana.devboard.local (login: admin)"
echo "  • Vault: http://vault.devboard.local (token: root)"
echo ""
echo ""

echo "=================================================="
echo "FIN DES TESTS"
echo "=================================================="
