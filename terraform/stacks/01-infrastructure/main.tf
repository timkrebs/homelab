terraform {
  required_version = ">= 1.5.0"

  # Terraform Cloud backend
  # Set TF_CLOUD_ORGANIZATION env var or configure organization below
  # Set TF_API_TOKEN env var for authentication
  cloud {
    workspaces {
      name = "proxmox-homelab"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_insecure

  ssh {
    agent    = false
    username = "root"
  }
}

# Control Plane Node
module "k8s_control_plane" {
  source = "../../modules/proxmox-vm"

  vm_name     = "k8s-cp-01"
  target_node = var.proxmox_node
  clone       = var.template_vm_id

  cores  = 4
  memory = 8192

  disk = {
    size    = 50
    storage = var.storage_pool
  }

  network = {
    bridge  = "vmbr0"
    ip      = "192.168.1.110/24"
    gateway = "192.168.1.1"
  }

  cloud_init = {
    user     = var.vm_user
    ssh_keys = [var.ssh_public_key]
  }

  tags = ["kubernetes", "control-plane"]
}

# Worker Nodes
module "k8s_workers" {
  source   = "../../modules/proxmox-vm"
  for_each = toset(["01", "02"])

  vm_name     = "k8s-wk-${each.key}"
  target_node = var.proxmox_node
  clone       = var.template_vm_id

  cores  = 4
  memory = 16384

  disk = {
    size    = 100
    storage = var.storage_pool
  }

  network = {
    bridge  = "vmbr0"
    ip      = "192.168.1.12${each.key}/24"
    gateway = "192.168.1.1"
  }

  cloud_init = {
    user     = var.vm_user
    ssh_keys = [var.ssh_public_key]
  }

  tags = ["kubernetes", "worker"]
}
