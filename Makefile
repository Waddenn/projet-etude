.PHONY: help dev up down build test lint scan deploy-dev deploy-staging

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Local Development ────────────────────────────────────────

up: ## Start all services locally
	docker compose up -d

down: ## Stop all services
	docker compose down

dev: ## Start backend + frontend in dev mode (requires local Go & Node)
	cd app/backend && go run ./cmd/main.go &
	cd app/frontend && npm run dev

logs: ## Show logs
	docker compose logs -f

# ─── Build ────────────────────────────────────────────────────

build-backend: ## Build backend Docker image
	docker build -t devboard/backend:latest -f app/backend/Dockerfile app/backend/

build-frontend: ## Build frontend Docker image
	docker build -t devboard/frontend:latest -f app/frontend/Dockerfile app/frontend/

build: build-backend build-frontend ## Build all Docker images

# ─── Test ─────────────────────────────────────────────────────

test-backend: ## Run backend tests
	cd app/backend && go test -v -race ./...

test-frontend: ## Run frontend tests
	cd app/frontend && npm run test

test: test-backend test-frontend ## Run all tests

# ─── Lint ─────────────────────────────────────────────────────

lint-backend: ## Lint backend
	cd app/backend && golangci-lint run ./...

lint-frontend: ## Lint frontend
	cd app/frontend && npm run lint

lint: lint-backend lint-frontend ## Lint all

# ─── Security ─────────────────────────────────────────────────

scan-backend: ## Scan backend image with Trivy
	trivy image devboard/backend:latest

scan-frontend: ## Scan frontend image with Trivy
	trivy image devboard/frontend:latest

scan: scan-backend scan-frontend ## Scan all images

# ─── Kubernetes ───────────────────────────────────────────────

deploy-dev: ## Deploy to dev environment
	kubectl apply -k k8s/overlays/dev/

deploy-staging: ## Deploy to staging environment
	kubectl apply -k k8s/overlays/staging/

deploy-prod: ## Deploy to prod environment
	kubectl apply -k k8s/overlays/prod/

helm-install: ## Install with Helm (dev)
	helm upgrade --install devboard helm/devboard/ -f helm/devboard/values-dev.yaml -n devboard-dev --create-namespace

helm-install-prod: ## Install with Helm (prod)
	helm upgrade --install devboard helm/devboard/ -f helm/devboard/values-prod.yaml -n devboard-prod --create-namespace

# ─── Proxmox Infrastructure ──────────────────────────────────

infra-up: ## Deploy full K3s infra on Proxmox (Terraform + Ansible)
	./scripts/infra-up.sh

infra-down: ## Destroy K3s infra on Proxmox
	./scripts/infra-down.sh

infra-init: ## Initialize Terraform
	cd infra/terraform && terraform init

infra-plan: ## Plan Terraform changes (preview LXC creation)
	cd infra/terraform && terraform plan

infra-apply: ## Apply Terraform changes (create LXC on Proxmox)
	cd infra/terraform && terraform apply

infra-destroy: ## Destroy Terraform resources (remove LXC from Proxmox)
	cd infra/terraform && terraform destroy

ansible-k3s: ## Install K3s via Ansible
	cd infra/ansible && ansible-playbook -i inventory/dev.yml playbooks/install-k3s.yml

ansible-tools: ## Deploy tools via Ansible (Prometheus, Grafana, Vault...)
	cd infra/ansible && ansible-playbook -i inventory/dev.yml playbooks/deploy-tools.yml

ssh-server: ## SSH into K3s server
	ssh root@192.168.1.40

ssh-agent1: ## SSH into K3s agent 1
	ssh root@192.168.1.41

ssh-agent2: ## SSH into K3s agent 2
	ssh root@192.168.1.42

# ─── ELK Demo ─────────────────────────────────────────────────

elk-up: ## Start ELK demo stack
	docker compose -f monitoring/elk-demo/docker-compose.yml up -d

elk-down: ## Stop ELK demo stack
	docker compose -f monitoring/elk-demo/docker-compose.yml down

# ─── Utilities ────────────────────────────────────────────────

seed: ## Seed database with sample data
	./scripts/seed-db.sh

benchmark: ## Run load test
	./scripts/benchmark.sh
