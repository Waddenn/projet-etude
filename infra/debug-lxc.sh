#!/bin/bash
# Debug LXC containers connectivity

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 -o LogLevel=ERROR"

echo "=== Checking LXC containers on Proxmox ==="
echo ""

for VMID in 400 401 402; do
  echo "--- Container $VMID ---"
  ssh $SSH_OPTS root@192.168.1.1 "pct status $VMID"
  ssh $SSH_OPTS root@192.168.1.1 "pct exec $VMID -- systemctl is-active ssh || pct exec $VMID -- systemctl is-active sshd" 2>/dev/null
  ssh $SSH_OPTS root@192.168.1.1 "pct exec $VMID -- ip addr show eth0 | grep 'inet '"
  echo ""
done

echo "=== Trying direct SSH to containers ==="
for IP in 192.168.1.40 192.168.1.41 192.168.1.42; do
  echo -n "SSH to $IP: "
  ssh $SSH_OPTS root@$IP "echo OK" 2>&1 || echo "FAILED"
done
