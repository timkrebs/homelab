variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g. https://192.168.1.128:8006)"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID (e.g. root@pam!terraform)"
}

variable "proxmox_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "proxmox_insecure" {
  type        = bool
  default     = true
  description = "Skip TLS verification for self-signed certs"
}

variable "proxmox_node" {
  type        = string
  default     = "pve01"
  description = "Target Proxmox node"
}

variable "template_vm_id" {
  type        = number
  default     = 9000
  description = "VM ID of the template to clone (ubuntu-server-jammy)"
}

variable "storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Storage pool for VM disks"
}

variable "vm_user" {
  type        = string
  default     = "ubuntu"
  description = "Default user for cloud-init VMs"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}
