terraform {
  required_version = ">= 1.5.0"

  # Terraform Cloud backend - organization set via TF_CLOUD_ORGANIZATION env var
  cloud {
    workspaces {
      name = "homelab-kubernetes"
    }
  }

  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = "~> 2.6"
    }
  }
}

# Reference outputs from 01-infrastructure via Terraform Cloud
data "terraform_remote_state" "infrastructure" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = "homelab-infrastructure"
    }
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

  timeout = "10m"

  commands = [
    # Install k3s server (conditionally add external IP if provided)
    "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${local.k3s_version} sh -s - server --cluster-init --disable traefik --disable servicelb --tls-san ${local.control_plane_ip}${var.k3s_external_ip != "" ? " --tls-san ${var.k3s_external_ip}" : ""}",
    # Wait for k3s to be ready
    "until sudo kubectl get nodes --kubeconfig /etc/rancher/k3s/k3s.yaml 2>/dev/null | grep -q Ready; do sleep 5; done"
  ]
}

# Get k3s node token separately for cleaner output parsing
resource "ssh_resource" "k3s_token" {
  host        = local.control_plane_ip
  user        = local.ssh_user
  private_key = var.ssh_private_key

  commands = [
    "sudo cat /var/lib/rancher/k3s/server/node-token"
  ]

  depends_on = [ssh_resource.k3s_control_plane]
}

# Install k3s on worker nodes
resource "ssh_resource" "k3s_workers" {
  for_each = toset(local.worker_ips)

  host        = each.value
  user        = local.ssh_user
  private_key = var.ssh_private_key

  timeout = "10m"

  commands = [
    "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${local.k3s_version} K3S_URL=https://${local.control_plane_ip}:6443 K3S_TOKEN=${trimspace(ssh_resource.k3s_token.result)} sh -"
  ]

  depends_on = [ssh_resource.k3s_token]
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
