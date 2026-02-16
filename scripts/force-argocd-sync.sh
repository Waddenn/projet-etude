#!/bin/bash
# Force la sychronisation de toutes les applications ArgoCD
# À exécuter depuis la machine locale avec accès à kubectl

echo "🔄 Synchronisation forcée des applications ArgoCD"
echo "=================================================="

export KUBECONFIG=${KUBECONFIG:-/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml}

# Applications à synchroniser
APPS=(
  "devboard-app"
  "monitoring-stack"
  "loki-stack"
  "vault"
  "ingress-services"
)

for app in "${APPS[@]}"; do
  echo ""
  echo "📦 Synchronisation: $app"
  kubectl patch application $app -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge 2>/dev/null || echo "⚠️  Application $app non trouvée"
  
  # Attendre un peu
  sleep 2
done

echo ""
echo "✅ Synchronisation demandée pour toutes les applications"
echo ""
echo "Vérifier le statut:"
echo "kubectl get applications -n argocd -o wide"
echo ""
echo "Ou via l'UI:"
echo "http://argocd.devboard.local"
