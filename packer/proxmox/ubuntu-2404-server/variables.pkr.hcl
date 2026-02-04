variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://pve01.proxcloud.io:8006/api2/json)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g., user@pam!token-name)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  default     = false
  description = "Skip TLS verification for Proxmox API"
}

variable "proxmox_node" {
  type        = string
  default     = "pve01"
  description = "Proxmox node name to build on"
}

variable "vm_id" {
  type        = number
  default     = 9000
  description = "VM ID for the template"
}

variable "storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for VM disk"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  default     = "packer"
  description = "SSH password for packer user during build (must match user-data)"
}
