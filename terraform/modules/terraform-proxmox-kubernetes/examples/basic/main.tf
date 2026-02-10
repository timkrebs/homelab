terraform {
  required_version = ">= 1.13.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent       = false
    username    = "root"
    private_key = var.ssh_private_key
  }
}

module "kubernetes" {
  source = "../../"

  cluster_name = "my-k3s-cluster"
  environment  = "dev"

  # Proxmox target
  proxmox_node = "pve"
  template_id  = 9000

  # Control plane sizing
  control_plane_instance_type = "t3.large"

  # Worker sizing
  worker_count         = 2
  worker_instance_type = "t3.xlarge"

  # Network
  network_bridge  = "vmbr0"
  network_gateway = "192.168.1.1"
  control_plane_ips = ["192.168.1.100/24"]
  worker_ips        = ["192.168.1.101/24", "192.168.1.102/24"]

  # SSH
  ssh_user        = "ubuntu"
  ssh_public_keys = [var.ssh_public_key]

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
