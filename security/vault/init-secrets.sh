#!/bin/bash
# Initialize Vault with DevBoard secrets
# Run this after Vault is deployed and unsealed

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export VAULT_ADDR

echo "Enabling KV secrets engine..."
vault secrets enable -path=secret kv-v2 2>/dev/null || true

echo "Writing DevBoard secrets..."
vault kv put secret/devboard/db \
  username=devboard \
  password=changeme-in-production \
  host=postgres \
  port=5432 \
  database=devboard

vault kv put secret/devboard/jwt \
  secret=changeme-jwt-secret-minimum-32-chars

echo "Writing Vault policy..."
vault policy write devboard /vault/policies/devboard-policy.hcl

echo "Enabling Kubernetes auth..."
vault auth enable kubernetes 2>/dev/null || true

vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc"

vault write auth/kubernetes/role/devboard \
  bound_service_account_names=devboard \
  bound_service_account_namespaces=devboard-dev,devboard-staging,devboard-prod \
  policies=devboard \
  ttl=1h

echo "Vault initialization complete."
