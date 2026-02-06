# -----------------------------------------------------------------------------
# Vault Enterprise HA Cluster Outputs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VM Information
# -----------------------------------------------------------------------------

output "haproxy_vm_id" {
  description = "HAProxy load balancer VM ID"
  value       = module.haproxy.vm_id
}

output "haproxy_ip" {
  description = "HAProxy load balancer IP address"
  value       = var.haproxy_ip
}

output "vault_node_vm_ids" {
  description = "Vault node VM IDs"
  value       = { for k, v in module.vault_nodes : k => v.vm_id }
}

output "vault_node_ips" {
  description = "Vault node IP addresses"
  value       = var.vault_ips
}

# -----------------------------------------------------------------------------
# Access URLs
# -----------------------------------------------------------------------------

output "vault_public_url" {
  description = "Vault public URL (via Cloudflare)"
  value       = "https://${var.vault_domain}"
}

output "vault_haproxy_url" {
  description = "Vault URL via HAProxy (direct)"
  value       = "https://${var.haproxy_ip}"
}

output "vault_node_urls" {
  description = "Direct URLs to each Vault node"
  value       = { for k, v in var.vault_ips : k => "https://${v}:8200" }
}

output "haproxy_stats_url" {
  description = "HAProxy stats dashboard URL"
  value       = "http://${var.haproxy_ip}:8404/stats"
}

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

output "vault_dns_record" {
  description = "Vault DNS record details"
  value = {
    name    = cloudflare_dns_record.vault.name
    type    = cloudflare_dns_record.vault.type
    content = cloudflare_dns_record.vault.content
    proxied = cloudflare_dns_record.vault.proxied
  }
}

# -----------------------------------------------------------------------------
# TLS Certificates
# -----------------------------------------------------------------------------

output "ca_certificate" {
  description = "CA certificate for Vault cluster (PEM)"
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}

output "ca_certificate_base64" {
  description = "CA certificate for Vault cluster (base64 encoded)"
  value       = base64encode(tls_self_signed_cert.ca.cert_pem)
  sensitive   = true
}

output "cloudflare_origin_cert_expires" {
  description = "Cloudflare origin certificate expiration date"
  value       = cloudflare_origin_ca_certificate.haproxy.expires_on
}

# -----------------------------------------------------------------------------
# Post-Deployment Instructions
# -----------------------------------------------------------------------------

output "post_deployment_instructions" {
  description = "Steps to complete after Terraform apply"
  value       = <<-EOT
    ============================================================
    VAULT ENTERPRISE HA CLUSTER DEPLOYED
    ============================================================

    1. RETRIEVE INIT KEYS (from vault-01):
       ssh ${var.vm_user}@${var.vault_ips["vault-01"]}
       sudo cat /opt/vault/init-keys.json

    2. UNSEAL VAULT-01 (leader):
       export VAULT_ADDR=https://${var.vault_ips["vault-01"]}:8200
       export VAULT_CACERT=/opt/vault/tls/ca-cert.pem
       vault operator unseal <key1>
       vault operator unseal <key2>
       vault operator unseal <key3>

    3. UNSEAL VAULT-02 AND VAULT-03:
       Repeat unseal process on each node.
       They will auto-join the cluster via retry_join.

    4. VERIFY HA STATUS:
       vault operator raft list-peers

    5. ACCESS VAULT:
       Public:  https://${var.vault_domain}
       Direct:  https://${var.haproxy_ip}
       HAProxy Stats: http://${var.haproxy_ip}:8404/stats

    ============================================================
    IMPORTANT: Store init keys securely! Delete from server!
    ============================================================
  EOT
}
