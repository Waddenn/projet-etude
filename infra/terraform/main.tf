terraform {
  required_version = ">= 1.5"
}

variable "node_count" {
  description = "Number of K3s agent nodes"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "Memory for K3s server (MB)"
  type        = number
  default     = 2048
}

variable "agent_memory" {
  description = "Memory for K3s agent nodes (MB)"
  type        = number
  default     = 1536
}

# ──────────────────────────────────────────────────────────────
# Local development with libvirt/Vagrant
# For cloud deployment, replace this block with your cloud provider
# (AWS, GCP, Azure, etc.)
# ──────────────────────────────────────────────────────────────

resource "null_resource" "k3s_server" {
  provisioner "local-exec" {
    command = "echo 'K3s server provisioning - replace with actual provider (libvirt, AWS, etc.)'"
  }
}

resource "null_resource" "k3s_agents" {
  count = var.node_count

  provisioner "local-exec" {
    command = "echo 'K3s agent ${count.index + 1} provisioning'"
  }
}

output "server_ip" {
  description = "K3s server IP"
  value       = "192.168.56.10"
}

output "agent_ips" {
  description = "K3s agent IPs"
  value       = [for i in range(var.node_count) : "192.168.56.${11 + i}"]
}
