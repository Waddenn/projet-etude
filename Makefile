.PHONY: help up down dev logs build test lint scan \
        infra-init infra-plan infra-apply infra-destroy infra-up \
        infra-up-strict \
        ansible-fix-lxc ansible-prepare ansible-k3s ansible-argocd \
        generate-secrets setup seed benchmark vault-init argocd-sync dns-setup verify \
        sync-k8s-secrets sync-vault-secrets

include config.env
ANSIBLE_FLAGS ?= --forks 20

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Local Development ────────────────────────────────────────

up: ## Start all services
	docker compose up -d

down: ## Stop all services
	docker compose down

dev: ## Start in dev mode (local Go + Node)
	cd app/backend && go run ./cmd/main.go &
	cd app/frontend && npm run dev

logs: ## Tail service logs
	docker compose logs -f

# ─── Build ────────────────────────────────────────────────────

build-backend: ## Build backend image
	docker build -t $(DOCKER_REGISTRY)/backend:latest -f app/backend/Dockerfile app/backend/

build-frontend: ## Build frontend image
	docker build -t $(DOCKER_REGISTRY)/frontend:latest -f app/frontend/Dockerfile app/frontend/

build: build-backend build-frontend ## Build all images

# ─── Test ─────────────────────────────────────────────────────

test-backend: ## Test backend
	cd app/backend && go test -v -race ./...

test-frontend: ## Test frontend
	cd app/frontend && npm test

test: test-backend test-frontend ## Run all tests

# ─── Lint ─────────────────────────────────────────────────────

lint-backend: ## Lint backend
	cd app/backend && golangci-lint run ./...

lint-frontend: ## Lint frontend
	cd app/frontend && npm run lint

lint: lint-backend lint-frontend ## Lint all

# ─── Security Scan ────────────────────────────────────────────

scan-backend: ## Scan backend with Trivy
	trivy image $(DOCKER_REGISTRY)/backend:latest

scan-frontend: ## Scan frontend with Trivy
	trivy image $(DOCKER_REGISTRY)/frontend:latest

scan: scan-backend scan-frontend ## Scan all images

# ─── Infrastructure ──────────────────────────────────────────

# Export Terraform-sensitive vars from .env.secrets
export TF_VAR_proxmox_password  ?= $(shell grep '^PROXMOX_PASSWORD=' .env.secrets 2>/dev/null | cut -d= -f2-)
export TF_VAR_lxc_root_password ?= $(shell grep '^LXC_ROOT_PASSWORD=' .env.secrets 2>/dev/null | cut -d= -f2-)

infra-init: ## Terraform init
	cd infra/terraform && terraform init

infra-plan: ## Terraform plan
	cd infra/terraform && terraform plan

infra-apply: ## Terraform apply (provision LXC)
	cd infra/terraform && terraform apply -auto-approve

infra-destroy: ## Terraform destroy (remove LXC)
	@printf "Destroy all infrastructure? [y/N] " && read ans && [ "$${ans}" = "y" ] && \
		(cd infra/terraform && terraform destroy) || echo "Aborted."

infra-up: infra-apply ansible-prepare ansible-k3s ansible-argocd dns-setup ## Full deploy pipeline (fast/idempotent path)

infra-up-strict: infra-apply _wait-ssh ansible-prepare ansible-k3s ansible-argocd-strict dns-setup ## Full deploy with strict readiness checks

_wait-ssh: ## (internal) Quick SSH check (Terraform already verified)
	@echo "Quick SSH verification..."
	@for ip in 192.168.1.40 192.168.1.41 192.168.1.42; do \
		printf "  $$ip..."; \
		for i in $$(seq 1 10); do \
			ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes root@$$ip true 2>/dev/null && printf " ok\n" && break; \
			[ $$i -eq 10 ] && printf " TIMEOUT\n" && exit 1; \
			sleep 2; \
		done; \
	done

# ─── Ansible ─────────────────────────────────────────────────

ansible-fix-lxc: ## Fix LXC configs for K3s
	cd infra/ansible && ansible-playbook $(ANSIBLE_FLAGS) -i inventory/dev.yml playbooks/fix-lxc-config.yml

ansible-prepare: ## Prepare containers for K3s
	cd infra/ansible && ansible-playbook $(ANSIBLE_FLAGS) -i inventory/dev.yml playbooks/prepare-lxc-k3s.yml

ansible-k3s: ## Install K3s cluster
	cd infra/ansible && ansible-playbook $(ANSIBLE_FLAGS) -i inventory/dev.yml playbooks/install-k3s.yml

ansible-argocd: ## Bootstrap ArgoCD + applications
	cd infra/ansible && ansible-playbook $(ANSIBLE_FLAGS) -i inventory/dev.yml playbooks/bootstrap-argocd.yml

ansible-argocd-strict: ## Bootstrap ArgoCD + applications (wait for sync)
	cd infra/ansible && ARGOCD_WAIT_INITIAL_SYNC=true ansible-playbook $(ANSIBLE_FLAGS) -i inventory/dev.yml playbooks/bootstrap-argocd.yml

# ─── Secrets & Setup ─────────────────────────────────────────

generate-secrets: ## Generate .env.secrets with random passwords
	@if [ -f .env.secrets ]; then \
		printf ".env.secrets exists. Overwrite? [y/N] " && read ans && [ "$${ans}" = "y" ] || exit 0; \
	fi
	@printf '%s\n' \
		'# DevBoard Secrets — $(shell date +%Y-%m-%d)' \
		'# DO NOT COMMIT (git-ignored)' \
		'' \
		'PROXMOX_PASSWORD=' \
		'LXC_ROOT_PASSWORD=' \
		'' \
		"DB_USERNAME=devboard" \
		"DB_PASSWORD=$$(openssl rand -base64 24 | tr -d '/+=')" \
		"DB_NAME=devboard" \
		'' \
		"JWT_SECRET=$$(openssl rand -base64 48 | tr -d '/+=')" \
		'' \
		"GRAFANA_ADMIN_PASSWORD=$$(openssl rand -base64 16 | tr -d '/+=')" \
		"VAULT_DEV_ROOT_TOKEN=root" \
		> .env.secrets
	@chmod 600 .env.secrets
	@echo "Generated .env.secrets — fill in PROXMOX_PASSWORD and LXC_ROOT_PASSWORD"

setup: ## First-time local setup (secrets + deps + postgres)
	@[ -f .env.secrets ] || $(MAKE) generate-secrets
	cd app/backend && go mod download
	cd app/frontend && npm ci
	docker compose up -d postgres
	@echo "Setup complete. Run 'make up' to start all services."

seed: ## Seed database with sample data
	@API=$${API_URL:-http://localhost:8080/api/v1}; \
	for p in \
		'{"name":"Portail Citoyen","client":"Mairie de Lyon","status":"in_progress","description":"Portail web pour les démarches administratives"}' \
		'{"name":"E-commerce PME","client":"Boulangerie Martin","status":"delivered","description":"Boutique en ligne avec paiement intégré"}' \
		'{"name":"App Mobile Santé","client":"Clinique du Parc","status":"draft","description":"Application de prise de rendez-vous"}' \
		'{"name":"Dashboard RH","client":"Groupe Nexia","status":"in_progress","description":"Tableau de bord RH avec indicateurs temps réel"}' \
		'{"name":"API Facturation","client":"Cabinet Durand","status":"delivered","description":"API REST de gestion de factures"}' \
		'{"name":"Refonte Intranet","client":"Région Occitanie","status":"draft","description":"Modernisation de l intranet régional"}'; \
	do curl -sf -X POST "$$API/projects" -H "Content-Type: application/json" -d "$$p" > /dev/null && \
		echo "  Created: $$(echo $$p | grep -o '"name":"[^"]*"' | cut -d'"' -f4)"; \
	done

sync-vault-secrets: ## Sync .env.secrets to Vault and refresh ExternalSecret
	@$(MAKE) vault-init
	@kubectl annotate externalsecret devboard-secrets -n default force-sync=$$(date +%s) --overwrite >/dev/null 2>&1 || true

sync-k8s-secrets: ## Backward-compatible alias (Vault is the source of truth)
	@echo "sync-k8s-secrets is deprecated; using Vault as source of truth."
	@$(MAKE) sync-vault-secrets

benchmark: ## Load test (requires hey: go install github.com/rakyll/hey@latest)
	hey -z $${DURATION:-30s} -c $${CONCURRENCY:-50} $${TARGET_URL:-http://localhost:8080}/api/v1/projects

vault-init: ## Initialize Vault with secrets from .env.secrets
	kubectl cp security/vault/policies/devboard-policy.hcl security/vault-0:/tmp/devboard-policy.hcl
	@. ./.env.secrets && \
	kubectl exec -n security vault-0 -- sh -c " \
		export VAULT_ADDR=http://127.0.0.1:8200 && \
		vault secrets enable -path=secret kv-v2 2>/dev/null; \
		vault kv put secret/devboard/db username=$${DB_USERNAME} password=$${DB_PASSWORD} host=postgres port=5432 database=$${DB_NAME} && \
		vault kv put secret/devboard/jwt secret=$${JWT_SECRET} && \
		vault kv put secret/devboard/grafana adminUser=admin adminPassword=$${GRAFANA_ADMIN_PASSWORD} && \
		vault policy write devboard /tmp/devboard-policy.hcl && \
		vault auth enable kubernetes 2>/dev/null; \
		vault write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc && \
		vault write auth/kubernetes/role/devboard bound_service_account_names=devboard \
			bound_service_account_namespaces=devboard-dev,devboard-staging,devboard-prod policies=devboard ttl=1h"
	@echo "Vault initialized."

argocd-sync: ## Force sync all ArgoCD applications
	@kubectl get applications -n argocd -o name | xargs -I{} kubectl patch {} -n argocd \
		-p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type merge

verify: ## Quick post-deploy verification (ArgoCD + workloads + recent warnings)
	@ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$(SERVER_IP) "\
		set -e; \
		echo '=== ArgoCD Applications ==='; \
		k3s kubectl get applications -n argocd -o wide; \
		echo; \
		echo '=== Non-ready Pods ==='; \
		k3s kubectl get pods -A --field-selector=status.phase!=Running; \
		echo; \
		echo '=== Recent Warning Events ==='; \
		k3s kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 25; \
	"

dns-setup: ## Add service domains to /etc/hosts
	@for host in dev.$(DOMAIN) argocd.$(DOMAIN) grafana.$(DOMAIN) prometheus.$(DOMAIN) alertmanager.$(DOMAIN) vault.$(DOMAIN); do \
		grep -Eq "(^|[[:space:]])$$host([[:space:]]|$$)" /etc/hosts 2>/dev/null || \
			echo "$(SERVER_IP) $$host" | sudo tee -a /etc/hosts > /dev/null; \
	done

ssh-server: ## SSH into K3s server
	ssh root@$(SERVER_IP)
