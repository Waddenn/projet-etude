output "server_ip" {
  description = "K3s server IP address"
  value       = var.server_ip
}

output "agent_ips" {
  description = "K3s agent IP addresses"
  value       = var.agent_ips
}

output "server_vmid" {
  description = "K3s server VMID"
  value       = proxmox_virtual_environment_container.k3s_server.vm_id
}

output "agent_vmids" {
  description = "K3s agent VMIDs"
  value       = [for agent in proxmox_virtual_environment_container.k3s_agent : agent.vm_id]
}

output "all_ips" {
  description = "All K3s node IPs (server first, then agents)"
  value       = concat([var.server_ip], var.agent_ips)
}
