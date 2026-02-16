# Proxmox connection
proxmox_endpoint = "https://192.168.40.1:8006"
proxmox_node     = "proxade"

# Auth: password-based (required for privileged LXC with feature flags)
proxmox_username = "root@pam"
# Set password via environment variable:
#   export TF_VAR_proxmox_password="your-root-password"

# LXC config
lxc_template        = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Set root password via environment variable:
#   export TF_VAR_lxc_root_password="your-password"

# Network
bridge  = "VLAN40"
gateway = "192.168.40.254"

# Storage
storage   = "Storage"
disk_size = 32

# K3s Server
server_vmid   = 400
server_ip     = "192.168.40.40"
server_cpu    = 4
server_memory = 4096

# K3s Agents
agent_count      = 2
agent_vmid_start = 401
agent_ips        = ["192.168.40.41", "192.168.40.42"]
agent_cpu        = 4
agent_memory     = 3072
