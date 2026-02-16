#!/bin/bash
# Tear down K3s infrastructure on Proxmox
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$(dirname "$SCRIPT_DIR")/infra/terraform"

echo "=== DevBoard Infrastructure Teardown ==="
echo ""
echo "This will destroy all K3s LXC containers on Proxmox."
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

cd "$TF_DIR"
terraform destroy -auto-approve

echo ""
echo "Infrastructure destroyed."
