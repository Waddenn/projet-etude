# 🔍 DIAGNOSTIC COMPLET - 16 février 2026

## État des services

| Service | Status HTTP | Statut | Route Traefik |
|---------|------------|--------|---------------|
| **ArgoCD** | 307 ✅ | Fonctionnel | argocd.devboard.local → argocd-server:80 |
| **Prometheus** | 302 ✅ | Fonctionnel | prometheus.devboard.local → prometheus-kube-prometheus-prometheus:9090 |
| **Grafana** | 404 ❌ | Problème | grafana.devboard.local → prometheus-grafana:80 |
| **Vault** | 307 ✅ | Fonctionnel | vault.devboard.local → vault:8200 |

---

## 🔧 Corrections apportées

### 1. Ingress corrigés
**Fichier** : [k8s/monitoring-ingress.yaml](k8s/monitoring-ingress.yaml)

Correction de 3 noms de services incorrects :

```yaml
# AVANT (incorrect)
- monitoring-stack-grafana       → INEXISTANT
- monitoring-stack-kube-prom-prometheus  → INEXISTANT  
- monitoring-stack-kube-prom-alertmanager → INEXISTANT

# APRÈS (correct)
- prometheus-grafana             ✅
- prometheus-kube-prometheus-prometheus ✅
- prometheus-kube-prometheus-alertmanager ✅
```

### 2. Configuration Grafana
**Problème** : Erreur de provisioning datasources
```
"Datasource provisioning error: datasource.yaml config is invalid. 
Only one datasource per organization can be marked as default"
```

**Solution** : Modification de la ConfigMap pour retirer `isDefault: true`

```yaml
# Avant
isDefault: true

# Après
isDefault: false
```

### 3. ArgoCD - Ingress services
**Fichier** : [argocd/applications/ingress-services.yaml](argocd/applications/ingress-services.yaml)

Ajout de l'ingress ArgoCD au contrôle GitOps :

```yaml
directory:
  include: '{ingress-argocd.yaml,monitoring-ingress.yaml,vault-ingress.yaml}'
```

### 4. Monitoring Stack - Ingress Grafana
**Fichier** : [argocd/applications/monitoring-stack.yaml](argocd/applications/monitoring-stack.yaml)

Activation de l'ingress dans la config Helm :

```yaml
grafana:
  ingress:
    enabled: true  # ✅ Était false
    ingressClassName: traefik
    hosts:
      - grafana.devboard.local
    path: /
```

---

## 📊 État actuel du cluster

### Pods et Services

**Argocd (namespace: argocd)**
```
Services:
✅ argocd-server (ClusterIP:80)
Endpoint: 10.42.3.23:8080
```

**Monitoring (namespace: monitoring)**
```
Services:
✅ prometheus-grafana (ClusterIP:80) - **Redéploiement en cours**
✅ prometheus-kube-prometheus-prometheus (ClusterIP:9090)
✅ prometheus-kube-prometheus-alertmanager (ClusterIP:9093)

Pods:
- prometheus-grafana-586988446b-* (2/3 containers) - Being healed
- prometheus-kube-prometheus-prometheus-0 (2/2) ✅

ConfigMaps:
✅ prometheus-kube-prometheus-grafana-datasource (Corrigée)
✅ loki-loki-stack (Peut avoir des conflits)
✅ loki-stack (Peut avoir des conflits)
```

**Security (namespace: security)**
```
Services:
✅ vault (ClusterIP:8200)
```

---

## 🚀 Prochaines actions

### Immédiate (1-2 min)
```bash
# Vérifier que Grafana a un endpoint
timeout 10 ssh root@192.168.1.40 "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get endpoints -n monitoring prometheus-grafana"

# Vérifier les pods Grafana
timeout 10 ssh root@192.168.1.40 "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana"
```

### Si Grafana affiche un 503 ou 502
```bash
# Redémarrer Traefik si nécessaire
timeout 10 ssh root@192.168.1.40 "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl rollout restart deployment -n kube-system traefik"
```

### Validation finale
```bash
# Dans ton /etc/hosts:
192.168.1.40 argocd.devboard.local prometheus.devboard.local grafana.devboard.local vault.devboard.local

# Puis:
curl -v http://grafana.devboard.local/  -H "Host: grafana.devboard.local"
```

---

## 📝 Fichiers modifiés

- ✅ [k8s/monitoring-ingress.yaml](k8s/monitoring-ingress.yaml) - Noms de services corrigés
- ✅ [argocd/applications/ingress-services.yaml](argocd/applications/ingress-services.yaml) - ArgoCD ingress inclus
- ✅ [argocd/applications/monitoring-stack.yaml](argocd/applications/monitoring-stack.yaml) - Grafana ingress activé
- ✅ [scripts/fix-grafana-datasource.sh](scripts/fix-grafana-datasource.sh) - Script de correction appliqué

---

## 🎯 Résumé

**Avant** : Seuls Prometheus et Vault accessibles
**Après** : 
- ✅ Prometheus accessibles
- ✅ Vault accessibles  
- ✅ ArgoCD accessibles (307 - redirect vers login)
- ⏳ Grafana en reconfiguration (redéploiement Grafana + correction ingress)

**ETA Grafana disponible** : ~5-10 minutes après le redéploiement du pod
