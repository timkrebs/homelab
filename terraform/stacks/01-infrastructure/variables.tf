variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "proxmox_insecure" {
  type        = bool
  default     = false
  description = "Skip TLS verification"
}

variable "proxmox_node" {
  type        = string
  default     = "pve01"
  description = "Target Proxmox node"
}

variable "storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for VM disks"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}
