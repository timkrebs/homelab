terraform {
  required_version = ">= 1.5.0"

  # Backend configuration - use local state for homelab
  # For production, consider using a remote backend like S3, GCS, or Terraform Cloud
  backend "local" {
    path = "terraform.tfstate"
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

# Template name variable - set to the Packer-built template
locals {
  ubuntu_template = var.vm_template_name
}

# Control Plane Node
module "k8s_control_plane" {
  source = "../../modules/proxmox-vm"

  vm_name     = "k8s-cp-01"
  target_node = var.proxmox_node
  clone       = local.ubuntu_template

  cores  = 4
  memory = 8192

  disk = {
    size    = 50
    storage = var.storage_pool
  }

  network = {
    bridge  = "vmbr0"
    ip      = "10.10.1.10/24"
    gateway = "10.10.0.1"
  }

  cloud_init = {
    user     = "ubuntu"
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
  clone       = local.ubuntu_template

  cores  = 4
  memory = 16384

  disk = {
    size    = 100
    storage = var.storage_pool
  }

  network = {
    bridge  = "vmbr0"
    ip      = "10.10.1.2${each.key}/24"
    gateway = "10.10.0.1"
  }

  cloud_init = {
    user     = "ubuntu"
    ssh_keys = [var.ssh_public_key]
  }

  tags = ["kubernetes", "worker"]
}
