# ------------------------------------------------------------------------------
# Namespace
# ------------------------------------------------------------------------------
resource "vault_namespace" "engineering" {
  path = var.engineering_namespace
}

# ------------------------------------------------------------------------------
# KV-V2 Secrets Engines
# ------------------------------------------------------------------------------
resource "vault_mount" "frontend_secrets" {
  namespace   = vault_namespace.engineering.path_fq
  path        = "frontend-secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "KV-V2 secrets engine for frontend team"
}

resource "vault_mount" "backend_secrets" {
  namespace   = vault_namespace.engineering.path_fq
  path        = "backend-secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "KV-V2 secrets engine for backend team"
}

# ------------------------------------------------------------------------------
# Frontend Secrets
# ------------------------------------------------------------------------------
resource "vault_kv_secret_v2" "frontend_app_config" {
  namespace = vault_namespace.engineering.path_fq
  mount     = vault_mount.frontend_secrets.path
  name      = "app-config"

  data_json = jsonencode({
    api_endpoint  = "https://api.example.com"
    cdn_url       = "https://cdn.example.com"
    analytics_key = "UA-12345678-1"
  })
}

resource "vault_kv_secret_v2" "frontend_auth" {
  namespace = vault_namespace.engineering.path_fq
  mount     = vault_mount.frontend_secrets.path
  name      = "auth"

  data_json = jsonencode({
    oauth_client_id    = "frontend-client-id"
    oauth_redirect_uri = "https://app.example.com/callback"
  })
}

# ------------------------------------------------------------------------------
# Backend Secrets
# ------------------------------------------------------------------------------
resource "vault_kv_secret_v2" "backend_app_config" {
  namespace = vault_namespace.engineering.path_fq
  mount     = vault_mount.backend_secrets.path
  name      = "app-config"

  data_json = jsonencode({
    jwt_secret     = var.backend_jwt_secret
    encryption_key = var.backend_encryption_key
    api_rate_limit = "1000"
  })
}

resource "vault_kv_secret_v2" "backend_external_services" {
  namespace = vault_namespace.engineering.path_fq
  mount     = vault_mount.backend_secrets.path
  name      = "external-services"

  data_json = jsonencode({
    payment_gateway_key   = var.payment_gateway_key
    email_service_api_key = var.email_service_api_key
  })
}

# ------------------------------------------------------------------------------
# Database Secrets Engine (Optional - requires PostgreSQL)
# Set enable_database_secrets = true in terraform.tfvars to enable
# ------------------------------------------------------------------------------
resource "vault_mount" "database" {
  count       = var.enable_database_secrets ? 1 : 0
  namespace   = vault_namespace.engineering.path_fq
  path        = "database"
  type        = "database"
  description = "Database secrets engine for dynamic credentials"
}

resource "vault_database_secret_backend_connection" "postgres" {
  count     = var.enable_database_secrets ? 1 : 0
  namespace = vault_namespace.engineering.path_fq
  backend   = vault_mount.database[0].path
  name      = "postgres-prod"

  allowed_roles = [
    "backend-readonly",
    "backend-readwrite"
  ]

  postgresql {
    connection_url = var.db_connection_url
    username       = var.db_admin_username
    password       = var.db_admin_password
  }
}

resource "vault_database_secret_backend_role" "backend_readonly" {
  count     = var.enable_database_secrets ? 1 : 0
  namespace = vault_namespace.engineering.path_fq
  backend   = vault_mount.database[0].path
  name      = "backend-readonly"
  db_name   = vault_database_secret_backend_connection.postgres[0].name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]

  revocation_statements = [
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]

  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours
}

resource "vault_database_secret_backend_role" "backend_readwrite" {
  count     = var.enable_database_secrets ? 1 : 0
  namespace = vault_namespace.engineering.path_fq
  backend   = vault_mount.database[0].path
  name      = "backend-readwrite"
  db_name   = vault_database_secret_backend_connection.postgres[0].name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]

  revocation_statements = [
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]

  default_ttl = 3600  # 1 hour
  max_ttl     = 28800 # 8 hours
}

# ------------------------------------------------------------------------------
# ACL Policies
# ------------------------------------------------------------------------------
resource "vault_policy" "frontend_engineer" {
  namespace = vault_namespace.engineering.path_fq
  name      = "frontend-engineer"

  policy = <<-EOT
    # Frontend Engineer Policy
    # Access to frontend KV-V2 secrets

    # Read and list frontend secrets
    path "frontend-secrets/data/*" {
      capabilities = ["read", "list"]
    }

    path "frontend-secrets/metadata/*" {
      capabilities = ["read", "list"]
    }

    # View own token information
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_policy" "backend_engineer" {
  namespace = vault_namespace.engineering.path_fq
  name      = "backend-engineer"

  policy = <<-EOT
    # Backend Engineer Policy
    # Access to backend KV-V2 secrets and database dynamic credentials

    # Read and list backend secrets
    path "backend-secrets/data/*" {
      capabilities = ["read", "list"]
    }

    path "backend-secrets/metadata/*" {
      capabilities = ["read", "list"]
    }

    # Request database dynamic credentials
    path "database/creds/backend-readonly" {
      capabilities = ["read"]
    }

    path "database/creds/backend-readwrite" {
      capabilities = ["read"]
    }

    # Manage leases (for DB credentials)
    path "sys/leases/renew" {
      capabilities = ["update"]
    }

    path "sys/leases/revoke" {
      capabilities = ["update"]
    }

    # View own token information
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
  EOT
}

# ------------------------------------------------------------------------------
# Identity Entities
# ------------------------------------------------------------------------------
resource "vault_identity_entity" "frontend_engineer" {
  namespace = vault_namespace.engineering.path_fq
  name      = "frontend-engineer"
  policies  = [vault_policy.frontend_engineer.name]

  metadata = {
    team = "frontend"
    role = "engineer"
  }
}

resource "vault_identity_entity" "backend_engineer" {
  namespace = vault_namespace.engineering.path_fq
  name      = "backend-engineer"
  policies  = [vault_policy.backend_engineer.name]

  metadata = {
    team = "backend"
    role = "engineer"
  }
}

# ------------------------------------------------------------------------------
# (Optional) Userpass Auth for Demo
# ------------------------------------------------------------------------------
resource "vault_auth_backend" "userpass" {
  namespace = vault_namespace.engineering.path_fq
  type      = "userpass"
  path      = "userpass"
}

resource "vault_generic_endpoint" "frontend_user" {
  namespace            = vault_namespace.engineering.path_fq
  path                 = "auth/userpass/users/frontend-dev"
  ignore_absent_fields = true

  data_json = jsonencode({
    password = var.demo_frontend_password
    policies = [vault_policy.frontend_engineer.name]
  })

  depends_on = [vault_auth_backend.userpass]
}

resource "vault_generic_endpoint" "backend_user" {
  namespace            = vault_namespace.engineering.path_fq
  path                 = "auth/userpass/users/backend-dev"
  ignore_absent_fields = true

  data_json = jsonencode({
    password = var.demo_backend_password
    policies = [vault_policy.backend_engineer.name]
  })

  depends_on = [vault_auth_backend.userpass]
}

resource "vault_identity_entity_alias" "frontend_alias" {
  namespace      = vault_namespace.engineering.path_fq
  name           = "frontend-dev"
  mount_accessor = vault_auth_backend.userpass.accessor
  canonical_id   = vault_identity_entity.frontend_engineer.id
}

resource "vault_identity_entity_alias" "backend_alias" {
  namespace      = vault_namespace.engineering.path_fq
  name           = "backend-dev"
  mount_accessor = vault_auth_backend.userpass.accessor
  canonical_id   = vault_identity_entity.backend_engineer.id
}

# ==============================================================================
# PKI Secrets Engine — Root CA
# ==============================================================================

resource "vault_mount" "pki_root" {
  count       = var.enable_pki ? 1 : 0
  path        = "pki"
  type        = "pki"
  description = "Root PKI Certificate Authority"

  default_lease_ttl_seconds = 86400     # 1 day
  max_lease_ttl_seconds     = 315360000 # 10 years
}

resource "vault_pki_secret_backend_root_cert" "root" {
  count       = var.enable_pki ? 1 : 0
  backend     = vault_mount.pki_root[0].path
  type        = "internal"
  common_name = "${var.pki_organization} Root CA"
  ttl         = var.pki_root_ttl

  organization = var.pki_organization
  key_type     = "rsa"
  key_bits     = 4096

  issuer_name = "root-ca"
}

resource "vault_pki_secret_backend_config_urls" "root_urls" {
  count   = var.enable_pki ? 1 : 0
  backend = vault_mount.pki_root[0].path

  issuing_certificates    = ["${var.vault_address}/v1/pki/ca"]
  crl_distribution_points = ["${var.vault_address}/v1/pki/crl"]
}

# ==============================================================================
# PKI Secrets Engine — Intermediate CA
# ==============================================================================

resource "vault_mount" "pki_int" {
  count       = var.enable_pki ? 1 : 0
  path        = "pki_int"
  type        = "pki"
  description = "Intermediate PKI CA for issuing certificates"

  default_lease_ttl_seconds = 86400     # 1 day
  max_lease_ttl_seconds     = 157680000 # 5 years
}

resource "vault_pki_secret_backend_intermediate_cert_request" "int_csr" {
  count       = var.enable_pki ? 1 : 0
  backend     = vault_mount.pki_int[0].path
  type        = "internal"
  common_name = "${var.pki_organization} Intermediate CA"

  organization = var.pki_organization
  key_type     = "rsa"
  key_bits     = 4096
}

resource "vault_pki_secret_backend_root_sign_intermediate" "int_signed" {
  count       = var.enable_pki ? 1 : 0
  backend     = vault_mount.pki_root[0].path
  csr         = vault_pki_secret_backend_intermediate_cert_request.int_csr[0].csr
  common_name = "${var.pki_organization} Intermediate CA"
  ttl         = var.pki_int_ttl

  organization = var.pki_organization

  depends_on = [vault_pki_secret_backend_root_cert.root]
}

resource "vault_pki_secret_backend_intermediate_set_signed" "int_set" {
  count       = var.enable_pki ? 1 : 0
  backend     = vault_mount.pki_int[0].path
  certificate = vault_pki_secret_backend_root_sign_intermediate.int_signed[0].certificate
}

resource "vault_pki_secret_backend_config_urls" "int_urls" {
  count   = var.enable_pki ? 1 : 0
  backend = vault_mount.pki_int[0].path

  issuing_certificates    = ["${var.vault_address}/v1/pki_int/ca"]
  crl_distribution_points = ["${var.vault_address}/v1/pki_int/crl"]
}

# ==============================================================================
# PKI Roles — Kubernetes TLS Certificates
# ==============================================================================

resource "vault_pki_secret_backend_role" "kubernetes_server" {
  count   = var.enable_pki ? 1 : 0
  backend = vault_mount.pki_int[0].path
  name    = "kubernetes-server"

  ttl     = var.pki_cert_ttl
  max_ttl = var.pki_cert_max_ttl

  allow_localhost    = true
  allowed_domains    = [var.pki_domain, "kubernetes", "kubernetes.default", "kubernetes.default.svc", "kubernetes.default.svc.cluster.local", "svc.cluster.local", "*.svc.cluster.local"]
  allow_subdomains   = true
  allow_bare_domains = true
  allow_glob_domains = true
  allow_ip_sans      = true
  server_flag        = true
  client_flag        = false

  key_type = "rsa"
  key_bits = 2048

  organization = [var.pki_organization]

  depends_on = [vault_pki_secret_backend_intermediate_set_signed.int_set]
}

resource "vault_pki_secret_backend_role" "kubernetes_client" {
  count   = var.enable_pki ? 1 : 0
  backend = vault_mount.pki_int[0].path
  name    = "kubernetes-client"

  ttl     = var.pki_cert_ttl
  max_ttl = var.pki_cert_max_ttl

  allow_localhost    = false
  allowed_domains    = [var.pki_domain, "svc.cluster.local"]
  allow_subdomains   = true
  allow_bare_domains = false
  allow_any_name     = false
  allow_ip_sans      = false
  server_flag        = false
  client_flag        = true

  key_type = "rsa"
  key_bits = 2048

  organization = [var.pki_organization]

  depends_on = [vault_pki_secret_backend_intermediate_set_signed.int_set]
}

resource "vault_pki_secret_backend_role" "wildcard" {
  count   = var.enable_pki ? 1 : 0
  backend = vault_mount.pki_int[0].path
  name    = "wildcard"

  ttl     = var.pki_cert_ttl
  max_ttl = var.pki_cert_max_ttl

  allow_localhost    = false
  allowed_domains    = [var.pki_domain]
  allow_subdomains   = true
  allow_bare_domains = true
  allow_glob_domains = true
  allow_ip_sans      = true
  server_flag        = true
  client_flag        = true

  key_type = "rsa"
  key_bits = 2048

  organization = [var.pki_organization]

  depends_on = [vault_pki_secret_backend_intermediate_set_signed.int_set]
}

# ==============================================================================
# ACME Configuration (Let's Encrypt via Vault PKI)
# Vault 1.14+ supports ACME protocol natively on the PKI engine
# ==============================================================================

resource "vault_generic_endpoint" "pki_int_acme_config" {
  count                = var.enable_pki && var.enable_acme ? 1 : 0
  path                 = "pki_int/config/cluster"
  ignore_absent_fields = true

  data_json = jsonencode({
    path     = "${var.vault_address}/v1/pki_int"
    aia_path = "${var.vault_address}/v1/pki_int"
  })

  depends_on = [vault_pki_secret_backend_intermediate_set_signed.int_set]
}

resource "vault_generic_endpoint" "pki_int_acme_enable" {
  count                = var.enable_pki && var.enable_acme ? 1 : 0
  path                 = "pki_int/config/acme"
  ignore_absent_fields = true

  data_json = jsonencode({
    enabled                  = true
    allow_role_ext_key_usage = false
    default_directory_policy = "role:wildcard"
  })

  depends_on = [
    vault_pki_secret_backend_role.wildcard,
    vault_generic_endpoint.pki_int_acme_config
  ]
}

# ==============================================================================
# PKI ACL Policies
# ==============================================================================

resource "vault_policy" "pki_issue" {
  count = var.enable_pki ? 1 : 0
  name  = "pki-issue"

  policy = <<-EOT
    # Issue certificates from the intermediate CA
    path "pki_int/issue/*" {
      capabilities = ["create", "update"]
    }

    path "pki_int/sign/*" {
      capabilities = ["create", "update"]
    }

    # Read CA chain for trust
    path "pki_int/ca/pem" {
      capabilities = ["read"]
    }

    path "pki_int/ca_chain" {
      capabilities = ["read"]
    }

    path "pki/ca/pem" {
      capabilities = ["read"]
    }

    # Revoke own certificates
    path "pki_int/revoke" {
      capabilities = ["create", "update"]
    }

    # List certificates
    path "pki_int/certs" {
      capabilities = ["list"]
    }
  EOT
}

resource "vault_policy" "pki_admin" {
  count = var.enable_pki ? 1 : 0
  name  = "pki-admin"

  policy = <<-EOT
    # Full PKI administration
    path "pki/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    path "pki_int/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }

    # Manage PKI roles
    path "pki_int/roles/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }

    # Tidy certificates
    path "pki_int/tidy" {
      capabilities = ["create", "update"]
    }
  EOT
}

# ==============================================================================
# Kubernetes Authentication Method
# ==============================================================================

resource "vault_auth_backend" "kubernetes" {
  count = var.enable_kubernetes_auth ? 1 : 0
  type  = "kubernetes"
  path  = "kubernetes"

  description = "Kubernetes auth method for K8s workloads"
}

resource "vault_kubernetes_auth_backend_config" "k8s_config" {
  count              = var.enable_kubernetes_auth ? 1 : 0
  backend            = vault_auth_backend.kubernetes[0].path
  kubernetes_host    = var.kubernetes_host
  kubernetes_ca_cert = var.kubernetes_ca_cert
}

# cert-manager role — allows cert-manager to issue certificates from Vault PKI
resource "vault_kubernetes_auth_backend_role" "cert_manager" {
  count                            = var.enable_kubernetes_auth && var.enable_pki ? 1 : 0
  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = "cert-manager"
  bound_service_account_names      = ["cert-manager"]
  bound_service_account_namespaces = ["cert-manager"]
  token_policies                   = ["pki-issue"]
  token_ttl                        = 3600
  token_max_ttl                    = 86400
}

# General workload role — allows K8s services to read engineering secrets
resource "vault_kubernetes_auth_backend_role" "workload" {
  count                            = var.enable_kubernetes_auth ? 1 : 0
  backend                          = vault_auth_backend.kubernetes[0].path
  role_name                        = "workload"
  bound_service_account_names      = ["*"]
  bound_service_account_namespaces = var.kubernetes_allowed_namespaces
  token_policies                   = ["backend-engineer"]
  token_ttl                        = 3600
  token_max_ttl                    = 28800
}

# ==============================================================================
# AppRole Auth — for CI/CD and automated certificate issuance
# ==============================================================================

resource "vault_auth_backend" "approle" {
  count       = var.enable_pki ? 1 : 0
  type        = "approle"
  path        = "approle"
  description = "AppRole auth for CI/CD pipelines and automation"
}

resource "vault_approle_auth_backend_role" "cert_issuer" {
  count          = var.enable_pki ? 1 : 0
  backend        = vault_auth_backend.approle[0].path
  role_name      = "cert-issuer"
  token_policies = ["pki-issue"]

  token_ttl     = 3600
  token_max_ttl = 14400

  secret_id_ttl      = 0 # Secret ID does not expire
  token_num_uses     = 0 # Unlimited token uses
  secret_id_num_uses = 0 # Unlimited secret ID uses
}

resource "vault_approle_auth_backend_role_secret_id" "cert_issuer" {
  count     = var.enable_pki ? 1 : 0
  backend   = vault_auth_backend.approle[0].path
  role_name = vault_approle_auth_backend_role.cert_issuer[0].role_name
}
