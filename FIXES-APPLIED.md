# 📋 RÉSUMÉ DES CORRECTIONS - Services K3s DevBoard

**Date** : 16 février 2026
**Problème rapporté** : Seuls Prometheus et Vault sont accessibles, pas ArgoCD ni Grafana

---

## ✅ Corrections appliquées

### 1. **Correction: ArgoCD Ingress non géré par ArgoCD** 
```yaml
# Fichier: argocd/applications/ingress-services.yaml
# Avant:
directory:
  include: '{monitoring-ingress.yaml,vault-ingress.yaml}'

# Après:
directory:
  include: '{ingress-argocd.yaml,monitoring-ingress.yaml,vault-ingress.yaml}'
```

**Impact** : ArgoCD va maintenant synchroniser et maintenir le manifeste `ingress-argocd.yaml`

---

### 2. **Correction: Grafana Ingress désactivé**
```yaml
# Fichier: argocd/applications/monitoring-stack.yaml
# Avant:
grafana:
  ingress:
    enabled: false

# Après:
grafana:
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - grafana.devboard.local
    path: /
```

**Impact** : Grafana sera exposé via Traefik à `http://grafana.devboard.local`

---

## 🚀 Actions maintenant à faire

### Phase 1: Synchronisation GitOps (5-10 minutes)

1. **Push les changements vers GitHub** :
   ```bash
   cd /home/tom/Dev/projet-etude
   git add -A
   git commit -m "fix: enable ArgoCD and Grafana ingress"
   git push origin main
   ```

2. **Forcer la synchronisation ArgoCD** (depuis ta machine) :
   ```bash
   export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
   
   # Patch l'application ingress-services pour forcer la sync
   kubectl patch application ingress-services -n argocd \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
     --type merge
   
   # Attendre la synchronisation
   sleep 30
   
   # Vérifier le statut
   kubectl get applications -n argocd -o wide
   ```

3. **Patcher monitoring-stack** :
   ```bash
   kubectl patch application monitoring-stack -n argocd \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
     --type merge
   ```

### Phase 2: Vérification

1. **Vérifier l'état des ingress** :
   ```bash
   export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml
   
   kubectl get ingress -A
   # Devrait montrer:
   # - argocd-server-ingress dans argocd
   # - grafana dans monitoring
   # - prometheus dans monitoring
   # - alertmanager dans monitoring
   # - vault-ingress dans security
   ```

2. **Vérifier les endpoints** :
   ```bash
   kubectl get endpoints -n argocd argocd-server
   kubectl get endpoints -n monitoring monitoring-stack-grafana
   ```

3. **Tester l'accès** :
   ```bash
   # Depuis ta machine, avec /etc/hosts configuré
   curl -s http://argocd.devboard.local | head -20
   curl -s http://grafana.devboard.local | head -20
   ```

### Phase 3: Validation dans le navigateur

1. **Ajouter dans `/etc/hosts`** :
   ```
   192.168.1.40 argocd.devboard.local
   192.168.1.40 grafana.devboard.local
   192.168.1.40 prometheus.devboard.local
   192.168.1.40 vault.devboard.local
   ```

2. **Accéder aux services** :
   - **ArgoCD** : http://argocd.devboard.local
     - Login : `admin` / `kzIumMQcQRRpLlLl`
     - Vérifier le statut des applications
   
   - **Grafana** : http://grafana.devboard.local
     - Login : `admin` / `admin` (ou `prom-operator` selon la config)
     - Vérifier les datasources Prometheus et Loki
   
   - **Prometheus** : http://prometheus.devboard.local
     - Vérifier les targets et métriques
   
   - **Vault** : http://vault.devboard.local
     - Token : `root`

---

## 🆘 Si ça ne marche pas

### Étape 1 : Diagnostic sur le master
```bash
# SSH vers le master K3s
ssh root@192.168.1.40

# Exécuter le diagnostic
bash ~/diagnostic-services.sh

# Vérifier les pods ArgoCD
kubectl -n argocd get pods -w
kubectl -n monitoring get pods -w
kubectl -n security get pods -w

# Vérifier les logs
kubectl logs -n argocd deployment/argocd-server | tail -50
kubectl logs -n monitoring deployment/kube-prometheus-operator | tail -50
```

### Étape 2 : Solution d'urgence - Appliquer manuellement
```bash
# SSH vers le master K3s
ssh root@192.168.1.40

# Copier le script d'urgence
scp /home/tom/Dev/projet-etude/scripts/apply-ingress-emergency.sh root@192.168.1.40:~/

# Exécuter
bash ~/apply-ingress-emergency.sh
```

### Étape 3 : Vérifier Traefik
```bash
ssh root@192.168.1.40

# Vérifier que Traefik tourne
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Logs Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50

# Vérifier les routes
kubectl get -n kube-system ingressroutes.traefik.containo.us
```

---

## 📊 Matrice de vérification

| Service | Ingress | Endpoint | Pod | Accessible |
|---------|---------|----------|-----|-----------|
| ArgoCD | ✅ Configuré | ? | ? | ? |
| Grafana | ✅ Configuré | ? | ? | ? |
| Prometheus | ✅ Déjà OK | ✅ | ✅ | ✅ |
| Vault | ✅ Déjà OK | ✅ | ✅ | ✅ |

---

## 📝 Notes importantes

1. **GitOps Flow** : Git → ArgoCD (détection 3 min) → Sync → Kubernetes
2. **Traefik** : Découvre automatiquement les Ingress via le IngressClass `traefik`
3. **Namespaces** : Chaque service a son namespace (argocd, monitoring, security)
4. **Bootstrap issue** : ArgoCD doit avoir un Ingress pour être accessible, mais l'Ingress peut être appliqué manuellement d'abord
5. **Endpoints** : Si pas d'endpoint, les pods ne répondent pas health check

---

## 🔗 Scripts utiles créés

- [`scripts/test-connectivity.sh`](../../scripts/test-connectivity.sh) - Test les connexions
- [`scripts/diagnostic-services.sh`](../../scripts/diagnostic-services.sh) - Diagnostic complet
- [`scripts/force-argocd-sync.sh`](../../scripts/force-argocd-sync.sh) - Force la sync
- [`scripts/apply-ingress-emergency.sh`](../../scripts/apply-ingress-emergency.sh) - Application manuelle

---

## ✉️ Prochaines étapes

1. **Valide les corrections** en poussant les fichiers modifiés vers Git
2. **Lance le diagnostic** sur le master pour identifier le problème réel
3. **Appelle le master** (root@192.168.1.40) pour appliquer les corrections si nécessaire
4. **Teste** l'accès aux services depuis ton navigateur
