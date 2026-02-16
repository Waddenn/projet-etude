terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true

  # Password auth required for privileged LXC with feature flags
  # (API tokens cannot set features on privileged containers)
  username = var.proxmox_username
  password = var.proxmox_password

  ssh {
    agent = true
  }
}

# ─── K3s Server ─────────────────────────────────────────────────

resource "proxmox_virtual_environment_container" "k3s_server" {
  description = "K3s server node - DevBoard project"

  node_name = var.proxmox_node
  vm_id     = var.server_vmid

  tags = ["devboard", "k3s", "server"]

  initialization {
    hostname = "k3s-server"

    ip_config {
      ipv4 {
        address = "${var.server_ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys     = [trimspace(file(var.ssh_public_key_path))]
      password = var.lxc_root_password
    }
  }

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.server_cpu
  }

  memory {
    dedicated = var.server_memory
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  # Required for K3s in LXC
  unprivileged = false
  features {
    nesting = true
    keyctl  = true
  }

  started       = true
  start_on_boot = true
}

# ─── K3s Agents ─────────────────────────────────────────────────

resource "proxmox_virtual_environment_container" "k3s_agent" {
  count       = var.agent_count
  description = "K3s agent node ${count.index + 1} - DevBoard project"

  node_name = var.proxmox_node
  vm_id     = var.agent_vmid_start + count.index

  tags = ["devboard", "k3s", "agent"]

  initialization {
    hostname = "k3s-agent-${count.index + 1}"

    ip_config {
      ipv4 {
        address = "${var.agent_ips[count.index]}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys     = [trimspace(file(var.ssh_public_key_path))]
      password = var.lxc_root_password
    }
  }

  operating_system {
    template_file_id = var.lxc_template
    type             = "debian"
  }

  cpu {
    cores = var.agent_cpu
  }

  memory {
    dedicated = var.agent_memory
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  # Required for K3s in LXC
  unprivileged = false
  features {
    nesting = true
    keyctl  = true
  }

  started       = true
  start_on_boot = true
}
