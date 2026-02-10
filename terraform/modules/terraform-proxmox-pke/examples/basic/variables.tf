variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API endpoint URL"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token (format: USER@REALM!TOKENID=SECRET)"
  sensitive   = true
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key for Proxmox host access (used by provider for file uploads)"
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}
