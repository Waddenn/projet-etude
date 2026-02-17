# ArgoCD GitOps Configuration

Ce répertoire contient les manifestes ArgoCD pour déployer automatiquement l'ensemble de la stack DevBoard.

## 📁 Structure

```
argocd/
├── projects/
│   └── devboard-project.yaml      # AppProject définissant les permissions
└── applications/
    ├── devboard-app.yaml          # Application principale (backend + frontend + postgres)
    ├── monitoring-stack.yaml      # Prometheus + Grafana
    ├── monitoring-dashboards.yaml # Dashboards Grafana (ConfigMaps)
    ├── loki-stack.yaml            # Loki + Promtail (logs)
    └── vault.yaml                 # HashiCorp Vault (secrets)
```

## 🚀 Déploiement

### 1. Appliquer le projet
```bash
kubectl apply -f argocd/projects/devboard-project.yaml
```

### 2. Appliquer toutes les applications
```bash
kubectl apply -f argocd/applications/
```

### 3. Vérifier l'état
```bash
# Via kubectl
kubectl get applications -n argocd

# Via ArgoCD CLI
argocd app list

# Via UI
http://argocd.devboard.local
```

## 🔄 Workflow GitOps

1. **Développeur** : Modifie `helm/devboard/values-dev.yaml`
2. **Git Push** : Push vers `main` (après PR approuvée)
3. **ArgoCD** : Détecte automatiquement le changement
4. **Sync** : Applique les modifications sur le cluster
5. **Self-Heal** : Corrige automatiquement si quelqu'un modifie manuellement

## ⚙️ Configuration des Applications

### DevBoard App
- **Path** : `helm/devboard`
- **Values** : `values-dev.yaml`
- **Namespace** : `default`
- **Auto-Sync** : ✅ Activé
- **Self-Heal** : ✅ Activé
- **Prune** : ✅ Activé (supprime ressources obsolètes)

### Monitoring Stack
- **Chart** : `kube-prometheus-stack`
- **Version** : 65.5.1
- **Namespace** : `monitoring`
- **Includes** : Prometheus, Grafana, Alertmanager

### Loki Stack
- **Chart** : `loki-stack`
- **Version** : 2.10.2
- **Namespace** : `monitoring`
- **Includes** : Loki, Promtail

### Vault
- **Chart** : `vault`
- **Version** : 0.28.1
- **Namespace** : `security`
- **Mode** : Dev (auto-unseal, token: root)

## 🔐 Accès ArgoCD

- **URL** : http://argocd.devboard.local
- **Username** : admin
- **Password** : Récupérer via :
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d && echo
  ```

## 📊 Commandes Utiles

```bash
# Synchroniser manuellement une app
argocd app sync devboard-app

# Forcer le refresh (rechecker Git)
argocd app get devboard-app --refresh

# Voir les différences
argocd app diff devboard-app

# Rollback à la version précédente
argocd app rollback devboard-app

# Voir l'historique
argocd app history devboard-app

# Supprimer une app (avec ressources)
argocd app delete devboard-app --cascade
```

## 🛠️ Troubleshooting

### App en état "OutOfSync"
```bash
# Vérifier les différences
argocd app diff <app-name>

# Synchroniser manuellement
argocd app sync <app-name>
```

### Self-Heal ne fonctionne pas
```bash
# Vérifier la config de l'app
kubectl get application <app-name> -n argocd -o yaml

# Vérifier que automated.selfHeal: true
```

### Images ne se téléchargent pas
```bash
# Vérifier imagePullPolicy dans values-dev.yaml
# Pour dev local : imagePullPolicy: Never
# Pour registry : imagePullPolicy: IfNotPresent ou Always
```

## 🔗 Ressources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [GitOps Principles](https://opengitops.dev/)
