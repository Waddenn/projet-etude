# État du projet DevBoard - 16 février 2026

## Ce qui a été fait

### Application "DevBoard"
- **Backend Go (Gin)** : `app/backend/` - API REST complète avec CRUD projets, endpoints `/health`, `/ready`, `/metrics` (Prometheus), middleware de métriques, Dockerfile multi-stage (image ~12 Mo)
- **Frontend React (Vite)** : `app/frontend/` - Dashboard avec stats, tableau de projets, formulaire de création, Dockerfile multi-stage (image ~25 Mo)
- **Docker Compose** : `docker-compose.yml` - Backend + Frontend + PostgreSQL pour le dev local

### CI/CD (GitHub Actions)
- **Pipeline principal** : `.github/workflows/ci.yml` - 7 étapes : lint → test → build → scan Trivy → deploy dev → deploy staging → deploy prod
- **Rollback** : `.github/workflows/rollback.yml` - Rollback manuel via workflow_dispatch
- Images publiées sur GitHub Container Registry (ghcr.io)

### Kubernetes
- **Manifestes Kustomize** : `k8s/base/` - Deployments, services, ingress, HPA (auto-scaling), NetworkPolicies
- **Overlays** : `k8s/overlays/dev|staging|prod/` - Variantes par environnement
- **Chart Helm** : `helm/devboard/` - Chart avec values par env (dev, prod)

### Infrastructure as Code (Proxmox)
- **Terraform** : `infra/terraform/` - Provider `bpg/proxmox`, crée 3 LXC Debian 12 privilegiés sur proxade (VMID 400-402, IPs 192.168.1.40-42)
- **Ansible** : `infra/ansible/` - Inventaire + playbooks pour installer K3s et déployer les outils (Prometheus, Grafana, Loki, Vault)

### Monitoring
- **Prometheus** : `monitoring/prometheus/custom-rules.yml` - 5 règles d'alerting (erreurs, latence, crash, replicas, CPU)
- **Loki** : `monitoring/loki/loki-config.yml` - Config logs
- **ELK demo** : `monitoring/elk-demo/docker-compose.yml` - Stack ELK minimale pour démo comparative

### Sécurité
- **Vault** : `security/vault/` - Config, policies, script d'init des secrets
- **Trivy** : `security/trivy/trivy-config.yml` - Config scan
- **RBAC** : `security/rbac/` - Roles K8s pour dev et prod

### Chaos Engineering
- **LitmusChaos** : `chaos/litmus/` - Scénarios pod-kill et network-loss

### Documentation
- **3 ADR** : `docs/adr/` - Choix K3s, Loki vs ELK, Go backend
- **README.md** : Présentation, stack, démarrage rapide, commandes
- **Makefile** : 25+ commandes (dev, build, test, lint, scan, deploy, infra, SSH)
- **Scripts** : setup-local, seed-db, benchmark, infra-up, infra-down

---

## Ce qu'il reste à faire

### Immédiat (pour que ça tourne)
   ```
2. **Installer K3s** via Ansible une fois les LXC créés
   ```bash
   cd infra/ansible
   ansible-playbook -i inventory/dev.yml playbooks/install-k3s.yml
   ```
3. **Déployer les outils** (Prometheus, Grafana, Loki, Vault)
   ```bash
   ansible-playbook -i inventory/dev.yml playbooks/deploy-tools.yml
   ```
4. **Résoudre les dépendances Go** : `cd app/backend && go mod tidy`
5. **Installer les deps frontend** : `cd app/frontend && npm install`

### Court terme
6. **Créer les 4 dashboards Grafana** (JSON) : applicatif, infra K8s, Green IT, sécurité
7. **Tester le pipeline GitHub Actions** : pousser sur GitHub et vérifier que le CI passe
8. **Configurer Vault** : exécuter `security/vault/init-secrets.sh` après déploiement
9. **Deployer l'app DevBoard sur K3s** : `make helm-install` ou `make deploy-dev`
10. **Créer les secrets K8s** pour la BDD et le JWT

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
