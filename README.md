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
| Logs | Loki + Promtail (+ démo ELK) |
| Sécurité | Trivy, HashiCorp Vault, RBAC K8s |
| IaC | Terraform + Ansible |
| Chaos Engineering | LitmusChaos |

## Démarrage rapide

```bash
# Prérequis : Docker, Go 1.22+, Node 20+

# Setup initial
./scripts/setup-local.sh

# Lancer tous les services
make up

# Ajouter des données de test
make seed

# Accéder à l'application
# Frontend : http://localhost:3000
# API :      http://localhost:8080/api/v1/projects
# Health :   http://localhost:8080/health
# Metrics :  http://localhost:8080/metrics
```

## Commandes utiles

```bash
make help          # Voir toutes les commandes
make build         # Construire les images Docker
make test          # Lancer les tests
make lint          # Linter le code
make scan          # Scanner les images avec Trivy
make deploy-dev    # Déployer en environnement dev (K8s)
make benchmark     # Lancer un test de charge
make elk-up        # Démarrer la stack ELK (démo)
```

## Architecture

```
                    GitHub Actions (CI/CD)
                         │
                    ┌────┴────┐
                    │ lint    │
                    │ test    │
                    │ build   │
                    │ scan    │
                    │ deploy  │
                    └────┬────┘
                         │
              ┌──────────┴──────────┐
              │   Cluster K3s       │
              │                     │
              │  Frontend ──► Backend ──► PostgreSQL
              │                │
              │           /metrics
              │                │
              │  Prometheus ◄──┘
              │      │
              │  Grafana (4 dashboards)
              │  Loki (logs)
              │  Vault (secrets)
              │  LitmusChaos (bonus)
              └─────────────────────┘
```

## Structure du projet

```
├── app/backend/       API Go (Gin)
├── app/frontend/      React (Vite)
├── infra/terraform/   Provisionnement VMs
├── infra/ansible/     Installation K3s et outils
├── k8s/               Manifestes Kubernetes (Kustomize)
├── helm/devboard/     Chart Helm
├── monitoring/        Grafana, Prometheus, Loki, ELK demo
├── security/          Vault, Trivy, RBAC
├── chaos/             Scénarios LitmusChaos
├── scripts/           Scripts utilitaires
├── docs/              Documentation et ADR
└── .github/workflows/ Pipeline CI/CD
```

## Documentation

- [Architecture technique](docs/architecture.md)
- [Guide d'installation](docs/installation-guide.md)
- [Guide utilisateur](docs/user-guide.md)
- [Guide d'administration](docs/admin-guide.md)
- [Rapport Green IT](docs/green-it-report.md)
- [Architecture Decision Records](docs/adr/)

## Équipe

| Rôle | Missions |
|------|----------|
| Lead CI/CD & App | Backend Go, pipeline GitHub Actions, stratégie de branching |
| Lead Infra & Orchestration | Terraform, Ansible, K8s, Helm, déploiement |
| Lead Monitoring & Green IT | Prometheus, Grafana, Loki, alerting, dashboards Green IT |
| Lead Sécu, Chaos & Docs | Vault, Trivy, RBAC, LitmusChaos, documentation |
