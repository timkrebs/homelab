provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token}=${var.proxmox_api_token_secret}"
  insecure  = true

  ssh {
    agent       = false
    username    = "root"
    private_key = var.ssh_private_key
  }
}

module "pke" {
  source = "../modules/terraform-proxmox-pke"

  cluster_name = "pke-vault-cluster"
  environment  = "prod"

  # Proxmox target
  proxmox_node = "pve01"
  template_id  = 9012

  # Control plane: 1 node (t3.small to match EKS worker sizing)
  control_plane_instance_type = "t3.small"
  control_plane_disk_size     = 50

  # Workers: 3 nodes matching the original EKS setup (2 + 1)
  worker_count         = 3
  worker_instance_type = "t3.small"
  worker_disk_size     = 50

  # Network
  network_bridge    = "vmbr0"
  network_gateway   = "192.168.1.1"
  control_plane_ips = ["192.168.1.160/24"]
  worker_ips        = ["192.168.1.161/24", "192.168.1.162/24", "192.168.1.163/24"]

  # SSH
  ssh_user        = "ubuntu"
  ssh_public_keys = [var.ssh_public_key]

  tags = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
