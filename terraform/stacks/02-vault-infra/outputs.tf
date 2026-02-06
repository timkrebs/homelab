output "namespace_path" {
  description = "Full path of the engineering namespace"
  value       = vault_namespace.engineering.path_fq
}

output "frontend_entity_id" {
  description = "Entity ID for frontend-engineer"
  value       = vault_identity_entity.frontend_engineer.id
}

output "backend_entity_id" {
  description = "Entity ID for backend-engineer"
  value       = vault_identity_entity.backend_engineer.id
}

output "secrets_engines" {
  description = "Paths of created secrets engines"
  value = {
    frontend_kv = vault_mount.frontend_secrets.path
    backend_kv  = vault_mount.backend_secrets.path
    database    = var.enable_database_secrets ? vault_mount.database[0].path : null
  }
}

output "database_roles" {
  description = "Available database roles"
  value = var.enable_database_secrets ? [
    vault_database_secret_backend_role.backend_readonly[0].name,
    vault_database_secret_backend_role.backend_readwrite[0].name
  ] : []
}

output "demo_users" {
  description = "Demo users for testing (userpass auth)"
  value = {
    frontend = "frontend-dev"
    backend  = "backend-dev"
  }
}

# ------------------------------------------------------------------------------
# PKI Outputs
# ------------------------------------------------------------------------------

output "pki_root_ca_cert" {
  description = "Root CA certificate (PEM) — add to trust stores"
  value       = var.enable_pki ? vault_pki_secret_backend_root_cert.root[0].certificate : null
  sensitive   = true
}

output "pki_intermediate_ca_cert" {
  description = "Intermediate CA certificate (PEM)"
  value       = var.enable_pki ? vault_pki_secret_backend_root_sign_intermediate.int_signed[0].certificate : null
  sensitive   = true
}

output "pki_paths" {
  description = "PKI secrets engine paths"
  value = var.enable_pki ? {
    root_ca         = vault_mount.pki_root[0].path
    intermediate_ca = vault_mount.pki_int[0].path
  } : null
}

output "pki_roles" {
  description = "Available PKI roles for certificate issuance"
  value = var.enable_pki ? {
    kubernetes_server = vault_pki_secret_backend_role.kubernetes_server[0].name
    kubernetes_client = vault_pki_secret_backend_role.kubernetes_client[0].name
    wildcard          = vault_pki_secret_backend_role.wildcard[0].name
  } : null
}

output "acme_directory_url" {
  description = "ACME directory URL for cert-manager or other ACME clients"
  value       = var.enable_pki && var.enable_acme ? "${var.vault_address}/v1/pki_int/acme/directory" : null
}

# ------------------------------------------------------------------------------
# Kubernetes Auth Outputs
# ------------------------------------------------------------------------------

output "kubernetes_auth_path" {
  description = "Kubernetes auth method mount path"
  value       = var.enable_kubernetes_auth ? vault_auth_backend.kubernetes[0].path : null
}

output "kubernetes_auth_roles" {
  description = "Available Kubernetes auth roles"
  value = var.enable_kubernetes_auth ? {
    cert_manager = var.enable_pki ? vault_kubernetes_auth_backend_role.cert_manager[0].role_name : null
    workload     = vault_kubernetes_auth_backend_role.workload[0].role_name
  } : null
}

# ------------------------------------------------------------------------------
# AppRole Outputs (for CI/CD)
# ------------------------------------------------------------------------------

output "approle_cert_issuer_role_id" {
  description = "AppRole Role ID for certificate issuer"
  value       = var.enable_pki ? vault_approle_auth_backend_role.cert_issuer[0].role_id : null
}

output "approle_cert_issuer_secret_id" {
  description = "AppRole Secret ID for certificate issuer"
  value       = var.enable_pki ? vault_approle_auth_backend_role_secret_id.cert_issuer[0].secret_id : null
  sensitive   = true
}
