# État du projet DevBoard - 16 février 2026 - 11h45

## ✅ Ce qui a été fait

### Application "DevBoard"
- **Backend Go (Gin)** : `app/backend/` - API REST complète avec CRUD projets, endpoints `/health`, `/ready`, `/metrics` (Prometheus), middleware de métriques, Dockerfile multi-stage (image ~12 Mo)
- **Frontend React (Vite)** : `app/frontend/` - Dashboard avec stats, tableau de projets, formulaire de création, Dockerfile multi-stage (image ~25 Mo)
- **Docker Compose** : `docker-compose.yml` - Backend + Frontend + PostgreSQL pour le dev local

### CI/CD (GitHub Actions)
- **Pipeline principal** : `.github/workflows/ci.yml` - 7 étapes : lint → test → build → scan Trivy → deploy dev → deploy staging → deploy prod
- **Rollback** : `.github/workflows/rollback.yml` - Rollback manuel via workflow_dispatch
- Images publiées sur GitHub Container Registry (ghcr.io)

### Kubernetes (DÉPLOYÉ ✅)
- **Manifestes Kustomize** : `k8s/base/` - Deployments, services, ingress, HPA (auto-scaling), NetworkPolicies
- **Overlays** : `k8s/overlays/dev|staging|prod/` - Variantes par environnement
- **Chart Helm** : `helm/devboard/` - Chart avec values par env (dev, prod)
  - Templates complétés : backend, frontend, postgres, ingress, secrets
  - Déployé en dev : 3 pods Running (backend, frontend, postgres)
  - Ingress Traefik : dev.devboard.local → backend/frontend
  - PVC : 1Gi pour PostgreSQL
- **Images Docker** : buildées et importées dans K3s (backend ~4Mo, frontend ~25Mo)
- **Namespaces** : devboard-dev, devboard-staging, devboard-prod créés

### Infrastructure as Code (Proxmox)
- **Terraform** : `infra/terraform/` - Provider `bpg/proxmox`, crée 3 LXC Debian 12 privilegiés sur proxade (VMID 400-402, IPs 192.168.1.40-42)
- **Ansible** : `infra/ansible/` - Inventaire + playbooks pour installer K3s et déployer les outils (Prometheus, Grafana, Loki, Vault)
- **K3s cluster** : 3 nœuds opérationnels (1 server + 2 agents), version v1.31.4+k3s1
- **LXC fixes** : configs pour K3s (privileged, proc/sys rw, kmsg, iptables, apparmor unconfined)

### Monitoring (DÉPLOYÉ ✅)
- **kube-prometheus-stack** : Déployé sur K3s (namespace `monitoring`)
  - Prometheus : scraping metrics de tous les pods/nodes
  - Grafana : accessible via port-forward 3000:80 (admin/admin)
  - Alertmanager : alertes configurées
  - Node exporters : sur les 3 nœuds
- **Loki + Promtail** : Logs centralisés (3 promtail sur chaque nœud)
- **Custom rules** : `monitoring/prometheus/custom-rules.yml` - 5 règles d'alerting (erreurs, latence, crash, replicas, CPU)
- **ELK demo** : `monitoring/elk-demo/docker-compose.yml` - Stack ELK minimale pour démo comparative

### Sécurité (DÉPLOYÉ ✅)
- **Vault** : Déployé sur K3s (namespace `security`, mode dev)
  - Secrets configurés : DB credentials, JWT secret
  - Policy devboard créée
  - Kubernetes auth activé pour les SA devboard
  - Accessible via port-forward 8200:8200
- **Trivy** : `security/trivy/trivy-config.yml` - Config scan
- **RBAC** : `security/rbac/` - Roles K8s pour dev et prod

### Chaos Engineering
- **LitmusChaos** : `chaos/litmus/` - Scénarios pod-kill et network-loss

### Documentation
- **3 ADR** : `docs/adr/` - Choix K3s, Loki vs ELK, Go backend
- **README.md** : Présentation, stack, démarrage rapide, commandes
- **SERVICES-ACCESS.md** : Guide complet d'accès à tous les services déployés ✅
- **Makefile** : 25+ commandes (dev, build, test, lint, scan, deploy, infra, SSH)
- **Scripts** : setup-local, seed-db, benchmark, infra-up, infra-down

---

## 🚀 État du déploiement

### ✅ Infrastructure opérationnelle
| Composant | Statut | Détails |
|-----------|--------|---------|
| **K3s Cluster** | ✅ Running | 3 nœuds Ready (192.168.1.40-42) |
| **Prometheus** | ✅ Running | Scraping actif, metrics OK |
| **Grafana** | ✅ Running | Port-forward 3000:80, admin/admin |
| **Loki** | ✅ Running | 3 promtail actifs (logs collectés) |
| **Vault** | ✅ Running | Mode dev, secrets configurés |
| **DevBoard Backend** | ✅ Running | /health OK, /metrics exposés |
| **DevBoard Frontend** | ✅ Running | http://dev.devboard.local |
| **PostgreSQL** | ✅ Running | PVC 1Gi, secrets Vault |
| **Traefik Ingress** | ✅ Running | Routing backend/frontend |

### 📝 Accès aux services
Voir **[docs/SERVICES-ACCESS.md](docs/SERVICES-ACCESS.md)** pour les détails complets.

---

## Ce qu'il reste à faire

### Court terme (priorité haute)
1. **Créer les 4 dashboards Grafana** (JSON) : applicatif, infra K8s, Green IT, sécurité
2. **Tester le pipeline GitHub Actions** : pousser sur GitHub et vérifier que le CI passe

### Moyen terme
11. **Tests unitaires Go** : écrire les tests pour handlers et repository
12. **Tests frontend** : ajouter des tests React (vitest)
13. **Compléter la doc** : `docs/architecture.md`, `docs/installation-guide.md`, `docs/user-guide.md`, `docs/admin-guide.md`
14. **Dashboard Green IT** : requêtes PromQL, mesures avant/après (tailles images, consommation CPU)
15. **LitmusChaos** : installer et tester les scénarios de chaos
16. **Tests de charge** : installer k6 et exécuter `scripts/benchmark.sh`
17. **Rapport Green IT** : `docs/green-it-report.md` avec chiffres et captures

### Pour la soutenance
18. **Vidéo MVP** (15-20 min) : screencast besoin → solution → démo live
19. **Rapport technique** (PDF groupe + PDF individuels)
20. **Préparer la démo chaos engineering live** sur Grafana
