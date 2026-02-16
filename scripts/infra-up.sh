#!/bin/bash
# Deploy full K3s infrastructure on Proxmox
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_DIR/infra/terraform"
ANSIBLE_DIR="$PROJECT_DIR/infra/ansible"
KUBECONFIG_PATH="$ANSIBLE_DIR/kubeconfig.yaml"

echo "=== DevBoard Infrastructure Deployment ==="
echo ""

# ─── Step 1: Terraform ──────────────────────────────────────────
echo "[1/5] Provisioning LXC containers with Terraform..."
cd "$TF_DIR"

if [ ! -d .terraform ]; then
  terraform init
fi

terraform apply -auto-approve
echo "LXC containers created."
echo ""

# ─── Step 2: Wait for SSH ────────────────────────────────────────
echo "[2/5] Waiting for containers to be reachable via SSH..."
SERVER_IP=$(terraform output -raw server_ip)
AGENT_IPS=$(terraform output -json agent_ips | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin)))")

ALL_IPS="$SERVER_IP $AGENT_IPS"

for ip in $ALL_IPS; do
  echo -n "  Waiting for $ip..."
  for i in $(seq 1 60); do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes root@"$ip" "true" 2>/dev/null; then
      echo " OK"
      break
    fi
    if [ "$i" -eq 60 ]; then
      echo " FAILED (timeout)"
      exit 1
    fi
    sleep 2
  done
done
echo ""

# ─── Step 3: Install K3s ────────────────────────────────────────
echo "[3/5] Installing K3s cluster via Ansible..."
cd "$ANSIBLE_DIR"
ansible-playbook -i inventory/dev.yml playbooks/install-k3s.yml
echo ""

# ─── Step 4: Deploy tools ───────────────────────────────────────
echo "[4/5] Deploying DevOps tools (Prometheus, Grafana, Loki, Vault)..."
ansible-playbook -i inventory/dev.yml playbooks/deploy-tools.yml
echo ""

# ─── Step 5: Verify ─────────────────────────────────────────────
echo "[5/5] Verifying cluster..."
export KUBECONFIG="$KUBECONFIG_PATH"
kubectl get nodes -o wide
echo ""
kubectl get pods -A
echo ""

echo "=== Infrastructure deployment complete! ==="
echo ""
echo "Kubeconfig: $KUBECONFIG_PATH"
echo "Usage:      export KUBECONFIG=$KUBECONFIG_PATH"
echo "K3s Server: ssh root@$SERVER_IP"
echo ""
echo "Dashboards (after port-forward):"
echo "  Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  Vault:   kubectl port-forward -n security svc/vault 8200:8200"
