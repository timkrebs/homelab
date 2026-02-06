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
  description = "VM template ID to clone (Ubuntu 24.04 Noble)"
  type        = number
  default     = 900
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

# -----------------------------------------------------------------------------
# K3s Control Plane Configuration
# -----------------------------------------------------------------------------

variable "control_plane_ip" {
  description = "IP address for the K3s control plane node"
  type        = string
  default     = "192.168.1.140"
}

variable "control_plane_cores" {
  description = "CPU cores for control plane node"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "Memory (MB) for control plane node"
  type        = number
  default     = 8192
}

variable "control_plane_disk_size" {
  description = "Disk size (GB) for control plane node"
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------------
# K3s Worker Node Configuration
# -----------------------------------------------------------------------------

variable "worker_ips" {
  description = "Map of worker node names to IP addresses"
  type        = map(string)
  default = {
    "k8s-worker-01" = "192.168.1.141"
    "k8s-worker-02" = "192.168.1.142"
  }
}

variable "worker_cores" {
  description = "CPU cores for each worker node"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory (MB) for each worker node"
  type        = number
  default     = 16384
}

variable "worker_disk_size" {
  description = "Disk size (GB) for each worker node"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# K3s Configuration
# -----------------------------------------------------------------------------

variable "k3s_version" {
  description = "K3s version to install (channel or explicit version)"
  type        = string
  default     = "v1.31.4+k3s1"
}

variable "k3s_cluster_cidr" {
  description = "CIDR range for pod network"
  type        = string
  default     = "10.42.0.0/16"
}

variable "k3s_service_cidr" {
  description = "CIDR range for service network"
  type        = string
  default     = "10.43.0.0/16"
}

variable "k3s_cluster_dns" {
  description = "Cluster DNS service IP (must be within service CIDR)"
  type        = string
  default     = "10.43.0.10"
}

# -----------------------------------------------------------------------------
# Vault Configuration (for TLS certificate issuance)
# -----------------------------------------------------------------------------

variable "vault_address" {
  description = "Vault cluster address (e.g., https://vault.proxcloud.io)"
  type        = string
}

variable "vault_token" {
  description = "Vault token with PKI issue permissions"
  type        = string
  sensitive   = true
}

variable "vault_skip_tls_verify" {
  description = "Skip TLS verification for Vault"
  type        = bool
  default     = false
}

variable "vault_pki_mount" {
  description = "Vault PKI intermediate mount path"
  type        = string
  default     = "pki_int"
}

variable "vault_pki_role" {
  description = "Vault PKI role for issuing K3s server certificates"
  type        = string
  default     = "kubernetes-server"
}

variable "vault_pki_cert_ttl" {
  description = "TTL for Vault-issued K3s TLS certificates"
  type        = string
  default     = "8760h"
}

# -----------------------------------------------------------------------------
# Cloudflare Configuration
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
