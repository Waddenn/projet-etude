# DevBoard - Plateforme CI/CD et Environnement DevOps Industrialisé

Projet d'étude M1 Mastère DevOps - Sup de Vinci 2025

## Présentation

DevBoard est une plateforme de gestion de projets pour ESN, servant de support à la démonstration d'un environnement DevOps industrialisé complet : CI/CD, conteneurisation, orchestration, monitoring, sécurité et Green IT.

## Stack technique

| Domaine | Outils |
|---------|--------|
| Application | Go (Gin) + React (Vite) + PostgreSQL |
| CI/CD | GitHub Actions |
| Conteneurisation | Docker (multi-stage) |
| Orchestration | K3s (Kubernetes certifié CNCF) |
| Monitoring | Prometheus + Grafana |
| Logs | Loki + Promtail |
| Sécurité | Trivy, HashiCorp Vault, RBAC K8s |
| IaC | Terraform + Ansible |
| Chaos Engineering | LitmusChaos |

## Démarrage rapide

```bash
# Prérequis : Docker, Go 1.22+, Node 20+

# Setup initial (génère les secrets + installe les dépendances)
make setup

# Lancer tous les services
make up

# Ajouter des données de test
make seed

## Commandes utiles

```bash
make help          # Voir toutes les commandes
make build         # Construire les images Docker
make test          # Lancer les tests
make lint          # Linter le code
make scan          # Scanner les images avec Trivy
make benchmark     # Lancer un test de charge
make infra-up      # Déployer le cluster K3s complet
make sync-vault-secrets # Synchroniser les secrets runtime vers Vault puis refresh ExternalSecret
```
## URLs d'accès

- Application: `http://dev.devboard.local`
- ArgoCD: `http://argocd.devboard.local`
- Grafana: `http://grafana.devboard.local`
- Prometheus: `http://prometheus.devboard.local`
- Alertmanager: `http://alertmanager.devboard.local`
- Vault: `http://vault.devboard.local`

## Équipe

| Rôle | Missions |
|------|----------|
| Lead CI/CD & App | Backend Go, pipeline GitHub Actions, stratégie de branching |
| Lead Infra & Orchestration | Terraform, Ansible, K8s, Helm, déploiement |
| Lead Monitoring & Green IT | Prometheus, Grafana, Loki, alerting, dashboards Green IT |
| Lead Sécu, Chaos & Docs | Vault, Trivy, RBAC, LitmusChaos, documentation |
