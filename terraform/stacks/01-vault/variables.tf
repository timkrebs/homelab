# -----------------------------------------------------------------------------
# Proxmox Connection Variables
# -----------------------------------------------------------------------------

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.1.128:8006)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID (e.g., root@pam!terraform)"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for self-signed certificates"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Target Proxmox node name"
  type        = string
  default     = "pve01"
}

# -----------------------------------------------------------------------------
# VM Template and Storage Variables
# -----------------------------------------------------------------------------

variable "template_vm_id" {
  description = "VM template ID to clone (Ubuntu 22.04)"
  type        = number
  default     = 9000
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "snippets_storage" {
  description = "Proxmox storage for cloud-init snippets (must support snippets content type)"
  type        = string
  default     = "local"
}

# -----------------------------------------------------------------------------
# SSH Access Variables
# -----------------------------------------------------------------------------

variable "vm_user" {
  description = "Cloud-init user for VM access"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  sensitive   = true
}

variable "ssh_private_key" {
  description = "SSH private key for Proxmox provider file uploads"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Vault Configuration Variables
# -----------------------------------------------------------------------------

variable "vault_version" {
  description = "Vault Enterprise version to install"
  type        = string
  default     = "1.18.4+ent"
}

variable "vault_license" {
  description = "Vault Enterprise license key"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Network Configuration Variables
# -----------------------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "haproxy_ip" {
  description = "HAProxy load balancer IP address"
  type        = string
  default     = "192.168.1.130"
}

variable "vault_ips" {
  description = "Map of Vault node names to IP addresses"
  type        = map(string)
  default = {
    "vault-01" = "192.168.1.131"
    "vault-02" = "192.168.1.132"
    "vault-03" = "192.168.1.133"
  }
}

# -----------------------------------------------------------------------------
# HAProxy Configuration Variables
# -----------------------------------------------------------------------------

variable "haproxy_cores" {
  description = "CPU cores for HAProxy VM"
  type        = number
  default     = 2
}

variable "haproxy_memory" {
  description = "Memory (MB) for HAProxy VM"
  type        = number
  default     = 2048
}

variable "haproxy_disk_size" {
  description = "Disk size (GB) for HAProxy VM"
  type        = number
  default     = 20
}

# -----------------------------------------------------------------------------
# Vault Node Configuration Variables
# -----------------------------------------------------------------------------

variable "vault_cores" {
  description = "CPU cores for each Vault node"
  type        = number
  default     = 2
}

variable "vault_memory" {
  description = "Memory (MB) for each Vault node"
  type        = number
  default     = 4096
}

variable "vault_disk_size" {
  description = "Disk size (GB) for each Vault node"
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------------
# Cloudflare Configuration Variables
# -----------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for proxcloud.io"
  type        = string
}

variable "cloudflare_zone" {
  description = "DNS zone domain name"
  type        = string
  default     = "proxcloud.io"
}

variable "vault_domain" {
  description = "Public domain for Vault access"
  type        = string
  default     = "vault.proxcloud.io"
}

# Note: cloudflare_proxied removed - private IPs cannot be proxied through Cloudflare

# -----------------------------------------------------------------------------
# TLS Configuration Variables
# -----------------------------------------------------------------------------

variable "tls_ca_validity_hours" {
  description = "Validity period for internal CA certificate (hours)"
  type        = number
  default     = 87600 # 10 years
}

variable "tls_cert_validity_hours" {
  description = "Validity period for node certificates (hours)"
  type        = number
  default     = 8760 # 1 year
}

# -----------------------------------------------------------------------------
# ACME / Let's Encrypt Configuration
# -----------------------------------------------------------------------------

variable "acme_server_url" {
  description = "ACME server URL. Use staging for testing, production for real certs."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  # Staging: "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME registration"
  type        = string
}

# Note: cloudflare_origin_cert_validity removed - using Let's Encrypt certs via ACME
