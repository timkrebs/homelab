terraform {
  required_version = ">= 1.5.0"

  # Backend configuration - use local state for homelab
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = "~> 2.6"
    }
  }
}

# Reference outputs from 01-infrastructure
data "terraform_remote_state" "infrastructure" {
  backend = "local"

  config = {
    path = "../01-infrastructure/terraform.tfstate"
  }
}

locals {
  control_plane_ip = data.terraform_remote_state.infrastructure.outputs.control_plane_ip
  worker_ips       = values(data.terraform_remote_state.infrastructure.outputs.worker_ips)
  ssh_user         = "ubuntu"
  k3s_version      = var.k3s_version
}

# Install k3s on control plane
resource "ssh_resource" "k3s_control_plane" {
  host        = local.control_plane_ip
  user        = local.ssh_user
  private_key = var.ssh_private_key

  timeout = "5m"

  commands = [
    # Install k3s server
    "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${local.k3s_version} sh -s - server --cluster-init --disable traefik --disable servicelb --tls-san ${local.control_plane_ip} --tls-san ${var.k3s_external_ip}",
    # Wait for k3s to be ready
    "until kubectl get nodes; do sleep 5; done",
    # Get node token for workers
    "sudo cat /var/lib/rancher/k3s/server/node-token"
  ]
}

# Install k3s on worker nodes
resource "ssh_resource" "k3s_workers" {
  for_each = toset(local.worker_ips)

  host        = each.value
  user        = local.ssh_user
  private_key = var.ssh_private_key

  timeout = "5m"

  commands = [
    "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${local.k3s_version} K3S_URL=https://${local.control_plane_ip}:6443 K3S_TOKEN=${ssh_resource.k3s_control_plane.result} sh -"
  ]

  depends_on = [ssh_resource.k3s_control_plane]
}

# Retrieve kubeconfig
resource "ssh_resource" "kubeconfig" {
  host        = local.control_plane_ip
  user        = local.ssh_user
  private_key = var.ssh_private_key

  commands = [
    "sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/${local.control_plane_ip}/g'"
  ]

  depends_on = [ssh_resource.k3s_control_plane]
}
