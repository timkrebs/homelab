# -----------------------------------------------------------------------------
# K3s Kubernetes Cluster on Proxmox
# Deploys 1 control plane + 2 worker nodes with Vault-issued TLS certificates
# Uses cloud-init for VM provisioning (compatible with HCP Terraform)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_insecure

  ssh {
    agent       = false
    username    = "root"
    private_key = var.ssh_private_key
  }
}

provider "vault" {
  address         = var.vault_address
  token           = var.vault_token
  skip_tls_verify = var.vault_skip_tls_verify
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# -----------------------------------------------------------------------------
# Pre-generated K3s cluster token
# Using random_password so workers can join without SSH provisioners.
# K3s accepts any string as --token; both server and agents use the same value.
# -----------------------------------------------------------------------------

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# -----------------------------------------------------------------------------
# Store K3s token in Vault KV for operational access
# -----------------------------------------------------------------------------

resource "vault_mount" "k3s_secrets" {
  path        = "k3s"
  type        = "kv"
  options     = { version = "2" }
  description = "K3s cluster secrets"
}

resource "vault_kv_secret_v2" "k3s_token" {
  mount = vault_mount.k3s_secrets.path
  name  = "cluster-token"

  data_json = jsonencode({
    token = random_password.k3s_token.result
  })
}

# -----------------------------------------------------------------------------
# Vault PKI — Issue TLS certificate for K3s API server
# Uses the kubernetes-server role on pki_int (created in 02-vault-infra)
# -----------------------------------------------------------------------------

resource "vault_pki_secret_backend_cert" "k3s_server" {
  backend = var.vault_pki_mount
  name    = var.vault_pki_role

  common_name = "k8s-control-01.${var.cloudflare_zone}"

  alt_names = [
    "k8s-control-01.${var.cloudflare_zone}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local",
    "localhost",
  ]

  ip_sans = [
    var.control_plane_ip,
    "10.43.0.1",
    "127.0.0.1",
  ]

  ttl = var.vault_pki_cert_ttl

  auto_renew = true
}

# -----------------------------------------------------------------------------
# Cloud-init Snippets (stored in Proxmox for VM bootstrap)
# Pattern: create proxmox_virtual_environment_file → pass .id to VM module
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_file" "k3s_server_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/k3s-server-cloud-init.yaml.tftpl", {
      node_ip      = var.control_plane_ip
      domain       = var.cloudflare_zone
      k3s_version  = var.k3s_version
      k3s_token    = random_password.k3s_token.result
      cluster_cidr = var.k3s_cluster_cidr
      service_cidr = var.k3s_service_cidr
      cluster_dns  = var.k3s_cluster_dns
      tls_cert     = vault_pki_secret_backend_cert.k3s_server.certificate
      tls_key      = vault_pki_secret_backend_cert.k3s_server.private_key
      tls_ca_chain = vault_pki_secret_backend_cert.k3s_server.ca_chain
    })
    file_name = "k3s-server-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_file" "k3s_agent_cloud_init" {
  for_each = var.worker_ips

  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/k3s-agent-cloud-init.yaml.tftpl", {
      node_name    = each.key
      server_ip    = var.control_plane_ip
      k3s_version  = var.k3s_version
      k3s_token    = random_password.k3s_token.result
      tls_ca_chain = vault_pki_secret_backend_cert.k3s_server.ca_chain
    })
    file_name = "k3s-${each.key}-cloud-init.yaml"
  }
}

# -----------------------------------------------------------------------------
# K3s Control Plane Node
# 2 vCPU / 8 GB RAM / 50 GB disk
# -----------------------------------------------------------------------------

module "k3s_control_plane" {
  source = "../../modules/proxmox-vm"

  vm_name     = "k8s-control-01"
  target_node = var.proxmox_node
  clone       = var.template_vm_id

  cores  = var.control_plane_cores
  memory = var.control_plane_memory

  disk = {
    size    = var.control_plane_disk_size
    storage = var.storage_pool
  }

  network = {
    bridge  = var.network_bridge
    ip      = "${var.control_plane_ip}/24"
    gateway = var.network_gateway
  }

  cloud_init = {
    user     = var.vm_user
    ssh_keys = [var.ssh_public_key]
  }

  user_data_file_id = proxmox_virtual_environment_file.k3s_server_cloud_init.id

  tags = ["kubernetes", "k3s", "control-plane"]
}

# -----------------------------------------------------------------------------
# K3s Worker Nodes
# 4 vCPU / 16 GB RAM / 100 GB disk each
# Workers depend on control plane to ensure ordering
# -----------------------------------------------------------------------------

module "k3s_workers" {
  source   = "../../modules/proxmox-vm"
  for_each = var.worker_ips

  vm_name     = each.key
  target_node = var.proxmox_node
  clone       = var.template_vm_id

  cores  = var.worker_cores
  memory = var.worker_memory

  disk = {
    size    = var.worker_disk_size
    storage = var.storage_pool
  }

  network = {
    bridge  = var.network_bridge
    ip      = "${each.value}/24"
    gateway = var.network_gateway
  }

  cloud_init = {
    user     = var.vm_user
    ssh_keys = [var.ssh_public_key]
  }

  user_data_file_id = proxmox_virtual_environment_file.k3s_agent_cloud_init[each.key].id

  tags = ["kubernetes", "k3s", "worker"]

  depends_on = [module.k3s_control_plane]
}

# -----------------------------------------------------------------------------
# Cloudflare DNS Records
# Private IPs cannot be proxied through Cloudflare
# -----------------------------------------------------------------------------

# Control plane DNS record
resource "cloudflare_dns_record" "k3s_control_plane" {
  zone_id = var.cloudflare_zone_id
  name    = "k8s-control-01"
  type    = "A"
  content = var.control_plane_ip
  ttl     = 300
  proxied = false
  comment = "K3s control plane node - managed by Terraform"
}

# Worker node DNS records
resource "cloudflare_dns_record" "k3s_workers" {
  for_each = var.worker_ips

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "A"
  content = each.value
  ttl     = 300
  proxied = false
  comment = "K3s worker node ${each.key} - managed by Terraform"
}

# Kubernetes API wildcard — points to control plane for kubectl access
resource "cloudflare_dns_record" "k8s_api" {
  zone_id = var.cloudflare_zone_id
  name    = "k8s"
  type    = "A"
  content = var.control_plane_ip
  ttl     = 300
  proxied = false
  comment = "K3s Kubernetes API endpoint - managed by Terraform"
}

# Wildcard for ingress — points to worker nodes for HTTP(S) traffic
resource "cloudflare_dns_record" "k8s_ingress" {
  for_each = var.worker_ips

  zone_id = var.cloudflare_zone_id
  name    = "*.k8s"
  type    = "A"
  content = each.value
  ttl     = 300
  proxied = false
  comment = "K3s ingress wildcard to ${each.key} - managed by Terraform"
}
