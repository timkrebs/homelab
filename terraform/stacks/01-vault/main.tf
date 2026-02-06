# -----------------------------------------------------------------------------
# Vault Enterprise HA Cluster
# Deploys 3-node Vault cluster with HAProxy load balancer on Proxmox
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

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# -----------------------------------------------------------------------------
# ACME Provider (Let's Encrypt)
# Uses DNS-01 challenge via Cloudflare for domain validation
# Works with private IPs since no inbound HTTP required
# -----------------------------------------------------------------------------

provider "acme" {
  server_url = var.acme_server_url
}

# -----------------------------------------------------------------------------
# Internal TLS Certificate Authority
# Used for Vault node-to-node and HAProxy-to-Vault communication
# -----------------------------------------------------------------------------

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "Vault CA"
    organization = "Homelab"
  }

  validity_period_hours = var.tls_ca_validity_hours
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

# -----------------------------------------------------------------------------
# Let's Encrypt TLS Certificate for HAProxy (public-facing)
# Uses DNS-01 challenge via Cloudflare — works with private IPs
# -----------------------------------------------------------------------------

resource "tls_private_key" "acme_account" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "acme_registration" "vault" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
  email_address   = var.acme_email
}

resource "tls_private_key" "haproxy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "haproxy" {
  private_key_pem = tls_private_key.haproxy.private_key_pem

  subject {
    common_name  = var.vault_domain
    organization = "Homelab"
  }

  dns_names = [
    var.vault_domain,
    "vault-lb.${var.cloudflare_zone}",
  ]
}

resource "acme_certificate" "haproxy" {
  account_key_pem         = acme_registration.vault.account_key_pem
  certificate_request_pem = tls_cert_request.haproxy.cert_request_pem

  dns_challenge {
    provider = "cloudflare"

    config = {
      CF_DNS_API_TOKEN = var.cloudflare_api_token
    }
  }
}

# -----------------------------------------------------------------------------
# Vault Node TLS Certificates
# One certificate per Vault node, signed by internal CA
# -----------------------------------------------------------------------------

resource "tls_private_key" "vault" {
  for_each  = var.vault_ips
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "vault" {
  for_each        = var.vault_ips
  private_key_pem = tls_private_key.vault[each.key].private_key_pem

  subject {
    common_name  = each.key
    organization = "Homelab"
  }

  dns_names = [
    each.key,
    "${each.key}.${var.cloudflare_zone}",
    "localhost",
    "vault.${var.cloudflare_zone}",
  ]

  ip_addresses = [
    each.value,
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "vault" {
  for_each = var.vault_ips

  cert_request_pem   = tls_cert_request.vault[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = var.tls_cert_validity_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# -----------------------------------------------------------------------------
# Cloud-init Snippets (stored in Proxmox for VM bootstrap)
# This replaces SSH provisioners - VMs configure themselves on first boot
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_file" "haproxy_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/haproxy-cloud-init.yaml.tftpl", {
      tls_cert    = "${acme_certificate.haproxy.certificate_pem}${acme_certificate.haproxy.issuer_pem}"
      tls_key     = tls_private_key.haproxy.private_key_pem
      tls_ca      = tls_self_signed_cert.ca.cert_pem
      vault_nodes = var.vault_ips
    })
    file_name = "haproxy-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_file" "vault_cloud_init" {
  for_each = var.vault_ips

  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/vault-cloud-init.yaml.tftpl", {
      vault_version = var.vault_version
      node_id       = each.key
      node_ip       = each.value
      is_leader     = each.key == "vault-01" ? "true" : "false"
      tls_cert      = tls_locally_signed_cert.vault[each.key].cert_pem
      tls_key       = tls_private_key.vault[each.key].private_key_pem
      tls_ca        = tls_self_signed_cert.ca.cert_pem
      vault_license = var.vault_license
      vault_nodes   = var.vault_ips
    })
    file_name = "vault-${each.key}-cloud-init.yaml"
  }
}

# -----------------------------------------------------------------------------
# HAProxy Load Balancer VM
# -----------------------------------------------------------------------------

module "haproxy" {
  source = "../../modules/proxmox-vm"

  vm_name     = "vault-lb"
  target_node = var.proxmox_node
  clone       = var.template_vm_id

  cores  = var.haproxy_cores
  memory = var.haproxy_memory

  disk = {
    size    = var.haproxy_disk_size
    storage = var.storage_pool
  }

  network = {
    bridge  = var.network_bridge
    ip      = "${var.haproxy_ip}/24"
    gateway = var.network_gateway
  }

  cloud_init = {
    user     = var.vm_user
    ssh_keys = [var.ssh_public_key]
  }

  user_data_file_id = proxmox_virtual_environment_file.haproxy_cloud_init.id

  tags = ["vault", "haproxy", "load-balancer"]
}

# -----------------------------------------------------------------------------
# Vault Enterprise Nodes (3-node HA cluster)
# -----------------------------------------------------------------------------

module "vault_nodes" {
  source   = "../../modules/proxmox-vm"
  for_each = var.vault_ips

  vm_name     = each.key
  target_node = var.proxmox_node
  clone       = var.template_vm_id

  cores  = var.vault_cores
  memory = var.vault_memory

  disk = {
    size    = var.vault_disk_size
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

  user_data_file_id = proxmox_virtual_environment_file.vault_cloud_init[each.key].id

  tags = ["vault", "enterprise", "ha"]
}

# -----------------------------------------------------------------------------
# Cloudflare DNS Records
# Note: Using proxied=false because private IPs cannot be proxied
# -----------------------------------------------------------------------------

# Main DNS record for vault.proxcloud.io -> HAProxy
resource "cloudflare_dns_record" "vault" {
  zone_id = var.cloudflare_zone_id
  name    = "vault"
  type    = "A"
  content = var.haproxy_ip
  ttl     = 300
  proxied = false # Private IPs cannot be proxied through Cloudflare
  comment = "Vault Enterprise HA cluster - managed by Terraform"
}

# Individual node DNS records (for direct access/debugging)
resource "cloudflare_dns_record" "vault_nodes" {
  for_each = var.vault_ips

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "A"
  content = each.value
  ttl     = 300
  proxied = false
  comment = "Vault Enterprise node ${each.key} - managed by Terraform"
}

# HAProxy load balancer DNS record
resource "cloudflare_dns_record" "vault_lb" {
  zone_id = var.cloudflare_zone_id
  name    = "vault-lb"
  type    = "A"
  content = var.haproxy_ip
  ttl     = 300
  proxied = false
  comment = "Vault HAProxy load balancer - managed by Terraform"
}
