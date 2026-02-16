# ─── Proxmox Connection ──────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox username (e.g. root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password for the user"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name to deploy on"
  type        = string
  default     = "proxade"
}

# ─── LXC Template ────────────────────────────────────────────────

variable "lxc_template" {
  description = "LXC template file ID"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}

variable "lxc_root_password" {
  description = "Root password for LXC containers"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key to inject into LXC containers"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ─── Network ─────────────────────────────────────────────────────

variable "bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "VLAN40"
}

variable "gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.40.254"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

# ─── Storage ─────────────────────────────────────────────────────

variable "storage" {
  description = "Proxmox storage for LXC root disks"
  type        = string
  default     = "Storage"
}

variable "disk_size" {
  description = "Root disk size in GiB"
  type        = number
  default     = 32
}

# ─── K3s Server ──────────────────────────────────────────────────

variable "server_vmid" {
  description = "VMID for K3s server"
  type        = number
  default     = 400
}

variable "server_ip" {
  description = "IP address for K3s server"
  type        = string
  default     = "192.168.40.40"
}

variable "server_cpu" {
  description = "CPU cores for K3s server"
  type        = number
  default     = 4
}

variable "server_memory" {
  description = "Memory in MiB for K3s server"
  type        = number
  default     = 4096
}

# ─── K3s Agents ──────────────────────────────────────────────────

variable "agent_count" {
  description = "Number of K3s agent nodes"
  type        = number
  default     = 2
}

variable "agent_vmid_start" {
  description = "Starting VMID for K3s agents"
  type        = number
  default     = 401
}

variable "agent_ips" {
  description = "IP addresses for K3s agents"
  type        = list(string)
  default     = ["192.168.40.41", "192.168.40.42"]
}

variable "agent_cpu" {
  description = "CPU cores for K3s agents"
  type        = number
  default     = 4
}

variable "agent_memory" {
  description = "Memory in MiB for K3s agents"
  type        = number
  default     = 3072
}
