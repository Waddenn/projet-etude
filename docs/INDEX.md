# Documentation DevBoard - Index

Bienvenue dans la documentation complète du projet DevBoard !

---

## 📚 Guide de lecture

### 🚀 Pour démarrer rapidement
1. [README.md](../README.md) - Vue d'ensemble et démarrage rapide
2. [SERVICES-ACCESS.md](SERVICES-ACCESS.md) - Accéder aux services déployés

### 🏗️ Architecture et Technique
3. [APPLICATION.md](APPLICATION.md) - Architecture de l'application (Backend Go, Frontend React, PostgreSQL)
4. [INFRASTRUCTURE.md](INFRASTRUCTURE.md) - Infrastructure (Terraform, Ansible, K3s)
5. [DEPLOYMENT.md](DEPLOYMENT.md) - Déploiement Helm et Kubernetes
6. [INGRESS-ROUTING-EXPLAINED.md](INGRESS-ROUTING-EXPLAINED.md) - Comment fonctionne le routage Ingress

### 📊 Monitoring et Observabilité
7. [MONITORING.md](MONITORING.md) - Prometheus, Grafana, Loki, Alertmanager

### 🔐 Sécurité
8. [SECURITY.md](SECURITY.md) - Vault, Trivy, RBAC, Network Policies

### 📖 Autres
9. [ETAT-PROJET.md](../ETAT-PROJET.md) - État d'avancement du projet
10. [ADR/](adr/) - Architecture Decision Records

---

## 📋 Par sujet

### Infrastructure

| Document | Contenu |
|----------|---------|
| [INFRASTRUCTURE.md](INFRASTRUCTURE.md) | Terraform, Ansible, K3s, LXC Proxmox, réseau |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Helm charts, Kustomize, namespaces, HPA |
| [INGRESS-ROUTING-EXPLAINED.md](INGRESS-ROUTING-EXPLAINED.md) | /etc/hosts, header Host:, Traefik routing |

### Application

| Document | Contenu |
|----------|---------|
| [APPLICATION.md](APPLICATION.md) | Backend Go (Gin), Frontend React (Vite), PostgreSQL, Docker |
| [SERVICES-ACCESS.md](SERVICES-ACCESS.md) | URLs, credentials, port-forward, SSH |

### Monitoring

| Document | Contenu |
|----------|---------|
| [MONITORING.md](MONITORING.md) | Prometheus, Grafana, Loki, Promtail, Alertmanager, PromQL, LogQL |

### Sécurité

| Document | Contenu |
|----------|---------|
| [SECURITY.md](SECURITY.md) | Vault, Trivy, RBAC, Secrets, Network Policies |

---

## 🎯 Guides par rôle

### Développeur

1. **Setup local** : [README.md](../README.md) → Section "Démarrage rapide"
2. **Architecture** : [APPLICATION.md](APPLICATION.md)
3. **API Backend** : [APPLICATION.md](APPLICATION.md) → Section "Backend Go"
4. **Frontend** : [APPLICATION.md](APPLICATION.md) → Section "Frontend React"
5. **Déployer** : [DEPLOYMENT.md](DEPLOYMENT.md) → Section "Déployer avec Helm"

### DevOps / SRE

1. **Infrastructure** : [INFRASTRUCTURE.md](INFRASTRUCTURE.md)
2. **K3s** : [INFRASTRUCTURE.md](INFRASTRUCTURE.md) → Section "K3s - Cluster Kubernetes"
3. **Monitoring** : [MONITORING.md](MONITORING.md)
4. **Alertes** : [MONITORING.md](MONITORING.md) → Section "Prometheus" et "Alertmanager"
5. **Sécurité** : [SECURITY.md](SECURITY.md)
6. **Dépannage** : [INFRASTRUCTURE.md](INFRASTRUCTURE.md) → Section "Dépannage"

### Product Owner / Manager

1. **Vue d'ensemble** : [README.md](../README.md)
2. **État du projet** : [ETAT-PROJET.md](../ETAT-PROJET.md)
3. **Accès aux services** : [SERVICES-ACCESS.md](SERVICES-ACCESS.md)
4. **Décisions architecturales** : [ADR/](adr/)

---

## 🔧 Commandes rapides

### Démarrer l'environnement

```bash
# Docker Compose (dev local)
docker-compose up -d

# Helm (K8s dev)
helm upgrade --install devboard helm/devboard/ \
  -f helm/devboard/values-dev.yaml \
  -n devboard-dev

# Vérifier le déploiement
kubectl get pods -n devboard-dev
```

### Accéder aux services

```bash
# Ajouter dans /etc/hosts
192.168.1.40 dev.devboard.local grafana.devboard.local prometheus.devboard.local

# URLs
http://dev.devboard.local          # DevBoard app
http://grafana.devboard.local      # Grafana (voir .env.secrets)
http://prometheus.devboard.local   # Prometheus
http://vault.devboard.local        # Vault (voir .env.secrets)
```

### Monitoring

```bash
# Voir les métriques Prometheus
curl http://dev.devboard.local/api/metrics

# Logs avec Loki (dans Grafana Explore)
{namespace="devboard-dev"}

# Health check
curl http://dev.devboard.local/api/health
```

### Debugging

```bash
# Logs d'un pod
kubectl logs -f <pod-name> -n devboard-dev

# Shell dans un pod
kubectl exec -it <pod-name> -n devboard-dev -- /bin/sh

# Events du namespace
kubectl get events -n devboard-dev --sort-by=.lastTimestamp

# Restart un deployment
kubectl rollout restart deployment devboard-backend -n devboard-dev
```

---

## 📖 Conventions de documentation

### Structure des documents

Chaque document suit cette structure :
1. **Vue d'ensemble** : Contexte et objectifs
2. **Architecture** : Schémas et diagrammes
3. **Configuration** : Fichiers et paramètres
4. **Utilisation** : Commandes et exemples
5. **Dépannage** : Problèmes fréquents et solutions
6. **Références** : Liens vers la doc officielle

### Symboles utilisés

- 🎯 **Rôle** : Description du rôle/objectif
- 📁 **Emplacement** : Chemin des fichiers
- 📋 **Configuration** : Paramètres et settings
- 🚀 **Commandes** : Exemples d'utilisation
- 🔧 **Outils** : Technologies utilisées
- 📊 **Données** : Structures et schémas
- 🔍 **Exemples** : Cas d'usage
- 🔐 **Sécurité** : Aspects sécurité
- ⚠️ **Attention** : Points importants
- ✅ **Bonnes pratiques** : Recommandations
- 📚 **Références** : Documentation externe

---

## 🤝 Contribuer à la documentation

### Ajouter une nouvelle page

1. Créer le fichier dans `docs/`
2. Ajouter l'entrée dans cet index
3. Respecter la structure commune
4. Utiliser les symboles appropriés
5. Ajouter des exemples concrets
6. Inclure des références externes

### Mettre à jour une page

1. Vérifier que l'info est toujours à jour
2. Ajouter/modifier les sections nécessaires
3. Mettre à jour la date si pertinent
4. Tester les commandes/exemples

---

## 📞 Support

### Problème avec l'infrastructure
→ Voir [INFRASTRUCTURE.md](INFRASTRUCTURE.md) → Section "Dépannage"

### Problème avec l'application
→ Voir [APPLICATION.md](APPLICATION.md) → Section "Dépannage"

### Problème de déploiement
→ Voir [DEPLOYMENT.md](DEPLOYMENT.md) → Section "Dépannage"

### Logs et monitoring
→ Voir [MONITORING.md](MONITORING.md) → Section "Loki"

### Accès aux services
→ Voir [SERVICES-ACCESS.md](SERVICES-ACCESS.md)

---

## 📅 Historique

| Date       | Version | Changement                                  |
|------------|---------|---------------------------------------------|
| 2026-02-16 | 1.0     | Création initiale de toute la documentation |

---

**Dernière mise à jour** : 16 février 2026
**Maintenu par** : Équipe DevBoard
