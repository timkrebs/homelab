terraform {
  required_version = ">= 1.5.0"

  # Terraform Cloud backend - organization set via TF_CLOUD_ORGANIZATION env var
  # Token set via TF_API_TOKEN env var
  cloud {
    workspaces {
      name = "homelab-infrastructure"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.80"
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

# HCP Provider - credentials via HCP_CLIENT_ID, HCP_CLIENT_SECRET env vars
provider "hcp" {}

# Get latest Ubuntu template from HCP Packer
data "hcp_packer_artifact" "ubuntu" {
  bucket_name  = "ubuntu-2404-server"
  channel_name = "latest"
  platform     = "proxmox"
  region       = var.proxmox_node
}

# Control Plane Node
module "k8s_control_plane" {
  source = "../../modules/proxmox-vm"

  vm_name     = "k8s-cp-01"
  target_node = var.proxmox_node
  clone       = data.hcp_packer_artifact.ubuntu.external_identifier

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
  clone       = data.hcp_packer_artifact.ubuntu.external_identifier

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
