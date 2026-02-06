variable "vault_address" {
  description = "HCP Vault cluster address"
  type        = string
}

variable "vault_token" {
  description = "Vault token with admin privileges"
  type        = string
  sensitive   = true
}

variable "engineering_namespace" {
  description = "Name of the engineering namespace"
  type        = string
  default     = "engineering"
}

variable "enable_database_secrets" {
  description = "Enable database secrets engine (requires PostgreSQL)"
  type        = bool
  default     = false
}

variable "db_connection_url" {
  description = "Database connection URL"
  type        = string
  default     = "postgresql://{{username}}:{{password}}@localhost:5432/mydb?sslmode=disable"
}

variable "db_admin_username" {
  description = "Database admin username for Vault"
  type        = string
  default     = "vault_admin"
}

variable "db_admin_password" {
  description = "Database admin password for Vault"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

# ------------------------------------------------------------------------------
# Demo Secrets (move to a secrets manager in production)
# ------------------------------------------------------------------------------

variable "backend_jwt_secret" {
  description = "JWT secret for backend app-config"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

variable "backend_encryption_key" {
  description = "Encryption key for backend app-config"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

variable "payment_gateway_key" {
  description = "Payment gateway API key for backend external-services"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

variable "email_service_api_key" {
  description = "Email service API key for backend external-services"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

variable "demo_frontend_password" {
  description = "Password for frontend-dev demo user"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

variable "demo_backend_password" {
  description = "Password for backend-dev demo user"
  type        = string
  sensitive   = true
  default     = "REPLACE_ME"
}

# ------------------------------------------------------------------------------
# PKI Configuration
# ------------------------------------------------------------------------------

variable "enable_pki" {
  description = "Enable PKI secrets engine for certificate management"
  type        = bool
  default     = true
}

variable "pki_domain" {
  description = "Base domain for PKI certificates"
  type        = string
  default     = "proxcloud.io"
}

variable "pki_organization" {
  description = "Organization name for PKI certificates"
  type        = string
  default     = "Homelab"
}

variable "pki_root_ttl" {
  description = "TTL for root CA certificate (default: 10 years)"
  type        = string
  default     = "87600h"
}

variable "pki_int_ttl" {
  description = "TTL for intermediate CA certificate (default: 5 years)"
  type        = string
  default     = "43800h"
}

variable "pki_cert_ttl" {
  description = "Default TTL for issued certificates (default: 30 days)"
  type        = string
  default     = "720h"
}

variable "pki_cert_max_ttl" {
  description = "Maximum TTL for issued certificates (default: 90 days)"
  type        = string
  default     = "2160h"
}

# ------------------------------------------------------------------------------
# Kubernetes Auth Configuration
# ------------------------------------------------------------------------------

variable "enable_kubernetes_auth" {
  description = "Enable Kubernetes auth method (configure after K8s cluster exists)"
  type        = bool
  default     = false
}

variable "kubernetes_host" {
  description = "Kubernetes API server address"
  type        = string
  default     = "https://kubernetes.default.svc"
}

variable "kubernetes_ca_cert" {
  description = "Kubernetes CA certificate (PEM encoded)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "kubernetes_allowed_namespaces" {
  description = "Namespaces allowed to authenticate via K8s auth"
  type        = list(string)
  default     = ["default", "kube-system", "cert-manager", "ingress-nginx"]
}

# ------------------------------------------------------------------------------
# ACME / Let's Encrypt Configuration
# ------------------------------------------------------------------------------

variable "enable_acme" {
  description = "Enable ACME protocol on PKI intermediate (Vault 1.14+). Allows cert-manager or other ACME clients to obtain certificates from Vault."
  type        = bool
  default     = false
}
