# 🔧 Troubleshooting - Services non accessibles

## Problèmes identifiés et corrections

### ✅ Corrections déjà appliquées

#### 1. **ArgoCD Ingress manquant** (CORRIGÉ)
- **Problème** : `argocd/applications/ingress-services.yaml` n'incluait pas `ingress-argocd.yaml`
- **Solution** : Ajouté `ingress-argocd.yaml` au `directory.include`
- **Fichier modifié** : [`argocd/applications/ingress-services.yaml`](../../argocd/applications/ingress-services.yaml)

#### 2. **Grafana non exposé** (CORRIGÉ)
- **Problème** : `grafana.ingress.enabled: false` dans Helm values
- **Solution** : Activé l'ingress Grafana dans `argocd/applications/monitoring-stack.yaml`
- **Fichier modifié** : [`argocd/applications/monitoring-stack.yaml`](../../argocd/applications/monitoring-stack.yaml)

---

## 🚀 Prochaines étapes

### 1. Forcer la synchronisation ArgoCD (depuis ta machine)
```bash
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml

# Forcer la sync de toutes les applications
bash /home/tom/Dev/projet-etude/scripts/force-argocd-sync.sh

# Ou individuellement
kubectl patch application ingress-services -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
  --type merge
```

### 2. Lancer le diagnostic complet (depuis le master K3s)
```bash
# SSH vers le master
ssh root@192.168.1.40

# Exécuter le diagnostic
bash ~root/diagnostic-services.sh
```

Copie le script sur le master d'abord :
```bash
scp /home/tom/Dev/projet-etude/scripts/diagnostic-services.sh root@192.168.1.40:~/
```

### 3. Vérifier que Prometheus et Vault restent accessibles
```bash
curl -s http://prometheus.devboard.local | head -20
curl -s http://vault.devboard.local | head -20
```

---

## 🔍 Vérifications supplémentaires

### A. Vérifier Traefik
```bash
# Via kubectl
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
```

### B. Vérifier les services dans chaque namespace
```bash
kubectl get svc -n argocd
kubectl get svc -n monitoring
kubectl get svc -n security
```

### C. Vérifier les ingress
```bash
kubectl get ingress -A
kubectl describe ingress -n argocd argocd-server-ingress
kubectl describe ingress -n monitoring grafana
```

### D. Vérifier les endpoints
```bash
# Que les pods sont réellement accessibles
kubectl get endpoints -n argocd
kubectl get endpoints -n monitoring
kubectl get endpoints -n security
```

---

## 📋 Checklist de validation
- [ ] Sync ArgoCD appliquée
- [ ] `http://argocd.devboard.local` accessible
- [ ] `http://grafana.devboard.local` accessible
- [ ] `http://prometheus.devboard.local` accessible
- [ ] `http://vault.devboard.local` accessible
- [ ] Prometheus scrape les métriques correctement
- [ ] Grafana peut requêter Prometheus

---

## 🆘 Si ça ne marche pas encore

1. **Vérifier les logs des pods** :
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
   kubectl logs -n monitoring -l app=kube-prometheus-operator
   kubectl logs -n security -l app.kubernetes.io/name=vault
   ```

2. **Vérifier la configuration Traefik** :
   ```bash
   kubectl get cm -n kube-system traefik
   kubectl describe cm -n kube-system traefik
   ```

3. **Vérifier les NetworkPolicies** :
   ```bash
   kubectl get networkpolicies -A
   # S'il y en a trop, elles peuvent bloquer le trafic
   ```

4. **Si L3s'attend à une correction DNS** :
   - Vérifier que `/etc/hosts` contient :
     ```
     192.168.1.40 argocd.devboard.local
     192.168.1.40 grafana.devboard.local
     192.168.1.40 prometheus.devboard.local
     192.168.1.40 vault.devboard.local
     ```

5. **Contacter le master pour vérifier** :
   ```bash
   ssh root@192.168.1.40
   kubectl get applications -n argocd
   kubectl describe application ingress-services -n argocd
   ```

---

## 💡 Notes importantes

- Les changements Git (fichiers YAML) sont détectés par ArgoCD (scan toutes les 3 min)
- L'ingress-services.yaml contrôle les ingress via GitOps
- Si un pod n'a pas d'endpoint, c'est qu'il ne démarre pas (regarder les logs)
- Traefik route automatiquement en se basant sur les règles d'ingress
