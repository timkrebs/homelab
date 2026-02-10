variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token (format: user@realm!tokenid=secret)"
  sensitive   = true
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key for Proxmox host access"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

variable "db_password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}
