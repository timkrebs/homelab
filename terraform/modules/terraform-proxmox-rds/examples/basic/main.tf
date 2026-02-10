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

module "db" {
  source = "../../"

  identifier     = "my-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.medium"

  allocated_storage = 50
  db_name           = "myapp"
  db_username       = "admin"
  db_password       = var.db_password
  port              = 5432

  # Proxmox target
  target_node = "pve"
  template_id = 9000

  # Network
  ip_address     = "192.168.1.60/24"
  gateway        = "192.168.1.1"
  network_bridge = "vmbr0"

  # SSH
  ssh_user        = "ubuntu"
  ssh_public_keys = [var.ssh_public_key]

  # Restrict access to local network
  allowed_cidrs = ["192.168.1.0/24"]

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}
