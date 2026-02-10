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

module "ec2_instance" {
  source = "../../"

  name          = "my-app-server"
  instance_type = "t3.medium"

  # Proxmox target
  target_node = "pve"
  template_id = 9000

  # Storage
  disk_size = 50

  # Network
  ip_address     = "192.168.1.50/24"
  gateway        = "192.168.1.1"
  network_bridge = "vmbr0"

  # SSH
  ssh_user        = "ubuntu"
  ssh_public_keys = [var.ssh_public_key]

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}
