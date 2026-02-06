# -----------------------------------------------------------------------------
# Vault Enterprise HA Cluster
# Deploys 3-node Vault cluster with HAProxy load balancer on Proxmox
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = var.proxmox_insecure

  ssh {
    agent    = false
    username = "root"
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
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

  tags = ["vault", "enterprise", "ha"]
}

# -----------------------------------------------------------------------------
# Internal TLS Certificate Authority
# Used for Vault cluster communication
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
# Cloudflare Origin CA Certificate
# Used for HAProxy TLS termination (trusted by Cloudflare edge)
# -----------------------------------------------------------------------------

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
    "*.${var.cloudflare_zone}",
  ]
}

resource "cloudflare_origin_ca_certificate" "haproxy" {
  csr                = tls_cert_request.haproxy.cert_request_pem
  hostnames          = [var.vault_domain, "*.${var.cloudflare_zone}"]
  request_type       = "origin-rsa"
  requested_validity = var.cloudflare_origin_cert_validity
}

# -----------------------------------------------------------------------------
# Wait for VMs to be ready
# -----------------------------------------------------------------------------

resource "null_resource" "wait_for_vms" {
  depends_on = [module.haproxy, module.vault_nodes]

  provisioner "local-exec" {
    command = "sleep 90"
  }
}

# -----------------------------------------------------------------------------
# HAProxy Installation and Configuration
# -----------------------------------------------------------------------------

resource "ssh_resource" "haproxy_install" {
  host        = var.haproxy_ip
  user        = var.vm_user
  private_key = var.ssh_private_key
  timeout     = "10m"

  depends_on = [null_resource.wait_for_vms]

  file {
    content = templatefile("${path.module}/templates/haproxy-init.sh.tftpl", {
      tls_combined = "${cloudflare_origin_ca_certificate.haproxy.certificate}\n${tls_private_key.haproxy.private_key_pem}"
      haproxy_config = templatefile("${path.module}/templates/haproxy.cfg.tftpl", {
        vault_nodes = var.vault_ips
      })
    })
    destination = "/tmp/haproxy-init.sh"
    permissions = "0755"
  }

  commands = [
    "chmod +x /tmp/haproxy-init.sh",
    "sudo /tmp/haproxy-init.sh",
  ]
}

# -----------------------------------------------------------------------------
# Vault Installation on Each Node
# -----------------------------------------------------------------------------

resource "ssh_resource" "vault_install" {
  for_each = var.vault_ips

  host        = each.value
  user        = var.vm_user
  private_key = var.ssh_private_key
  timeout     = "15m"

  depends_on = [null_resource.wait_for_vms]

  file {
    content = templatefile("${path.module}/templates/vault-init.sh.tftpl", {
      vault_version = var.vault_version
      node_id       = each.key
      is_leader     = each.key == "vault-01" ? "true" : "false"
      tls_cert      = tls_locally_signed_cert.vault[each.key].cert_pem
      tls_key       = tls_private_key.vault[each.key].private_key_pem
      tls_ca        = tls_self_signed_cert.ca.cert_pem
      vault_license = var.vault_license
      vault_config = templatefile("${path.module}/templates/vault-config.hcl.tftpl", {
        node_id     = each.key
        node_ip     = each.value
        vault_nodes = var.vault_ips
      })
      vault_service = file("${path.module}/templates/vault.service.tftpl")
    })
    destination = "/tmp/vault-init.sh"
    permissions = "0755"
  }

  commands = [
    "chmod +x /tmp/vault-init.sh",
    "sudo /tmp/vault-init.sh",
  ]
}

# -----------------------------------------------------------------------------
# Cloudflare DNS Records
# -----------------------------------------------------------------------------

# Main DNS record for vault.proxcloud.io -> HAProxy
resource "cloudflare_dns_record" "vault" {
  zone_id = var.cloudflare_zone_id
  name    = "vault"
  type    = "A"
  content = var.haproxy_ip
  ttl     = 1 # Auto (when proxied)
  proxied = var.cloudflare_proxied
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
