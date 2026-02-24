################################################################################
# Proxmox connection
################################################################################

variable "proxmox_api_url" {
  type        = string
  description = "Proxmox API URL (e.g., https://192.168.1.10:8006/api2/json)"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token ID (format: user@realm!tokenid)"
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret (UUID)"
  sensitive   = true
}

variable "ssh_private_key" {
  type        = string
  description = "SSH private key for Proxmox host access (used by bpg provider)"
  sensitive   = true
}

################################################################################
# VM identity
################################################################################

variable "vm_name" {
  type        = string
  description = "VM name shown in Proxmox and used as the Windows computer name"
  default     = "gaming-vm"
}

variable "vm_id" {
  type        = number
  default     = null
  description = "Proxmox VM ID (auto-assigned if null)"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node that owns the GPU (must be the node the Tesla is installed in)"
}

variable "template_id" {
  type        = number
  description = "Windows 11 VM template ID (sysprepped, cloudbase-init, VirtIO drivers, OVMF)"
}

################################################################################
# Sizing
################################################################################

variable "instance_type" {
  type        = string
  description = "Gaming instance size: g.medium / g.large / g.xlarge / g.2xlarge / custom"
  default     = "g.large"
}

################################################################################
# Storage
################################################################################

variable "disk_size" {
  type        = number
  description = "Root disk size in GB"
  default     = 256
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool"
  default     = "local-lvm"
}

################################################################################
# Network
################################################################################

variable "ip_address" {
  type        = string
  description = "Static IP in CIDR notation, e.g. '192.168.1.200/24'"
}

variable "network_gateway" {
  type        = string
  description = "Default gateway for the VM"
  default     = "192.168.1.1"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

################################################################################
# GPU passthrough
################################################################################

variable "gpu_pci_id" {
  type        = string
  description = "PCI address of Nvidia Tesla graphics function (e.g., '0000:01:00.0')"
}

variable "gpu_audio_pci_id" {
  type        = string
  default     = null
  description = "PCI address of GPU audio function (e.g., '0000:01:00.1'). null = skip."
}

variable "gpu_primary_display" {
  type        = bool
  default     = true
  description = "Set GPU as primary VGA (x_vga). Use false for secondary/headless-only."
}

################################################################################
# Windows credentials
################################################################################

variable "admin_username" {
  type        = string
  description = "Windows local administrator username"
  default     = "gamer"
}

variable "admin_password" {
  type        = string
  description = "Windows local administrator password"
  sensitive   = true
}

################################################################################
# Gaming software
################################################################################

variable "install_steam" {
  type        = bool
  description = "Install Steam during first boot"
  default     = true
}
