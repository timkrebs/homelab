################################################################################
# Instance Identity
################################################################################

variable "name" {
  type        = string
  description = "VM name (also used as Windows computer name)"
}

variable "vm_id" {
  type        = number
  default     = null
  description = "Proxmox VM ID (auto-assigned if not specified)"
}

################################################################################
# Instance Sizing
################################################################################

variable "instance_type" {
  type        = string
  description = "Gaming instance size: g.medium (4c/8GB), g.large (8c/16GB), g.xlarge (16c/32GB), g.2xlarge (32c/64GB), custom"
  default     = "g.large"

  validation {
    condition     = contains(["g.medium", "g.large", "g.xlarge", "g.2xlarge", "custom"], var.instance_type)
    error_message = "instance_type must be one of: g.medium, g.large, g.xlarge, g.2xlarge, custom."
  }
}

variable "custom_cores" {
  type        = number
  default     = null
  description = "CPU cores (only used when instance_type = 'custom')"
}

variable "custom_memory" {
  type        = number
  default     = null
  description = "Memory in MB (only used when instance_type = 'custom')"
}

################################################################################
# Proxmox Target
################################################################################

variable "target_node" {
  type        = string
  description = "Proxmox node name to deploy the VM on"
}

variable "template_id" {
  type        = number
  description = "Windows 11 VM template ID (must have cloudbase-init, VirtIO drivers, OVMF/vTPM pre-configured)"
}

################################################################################
# Storage
################################################################################

variable "disk_size" {
  type        = number
  description = "Root disk size in GB (100+ recommended for games)"
  default     = 256
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disk, EFI disk, and TPM state"
  default     = "local-lvm"
}

variable "snippets_storage" {
  type        = string
  description = "Proxmox storage for cloudbase-init snippets (must support 'snippets' content type)"
  default     = "local"
}

################################################################################
# Network
################################################################################

variable "ip_address" {
  type        = string
  description = "Static IP in CIDR notation (e.g., '192.168.1.200/24')"
}

variable "gateway" {
  type        = string
  description = "Network gateway IP"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

################################################################################
# GPU Passthrough
################################################################################

variable "gpu_pci_id" {
  type        = string
  description = "PCI address of the GPU graphics function (e.g., '0000:01:00.0'). Run 'lspci' on the Proxmox host to find it."
}

variable "gpu_audio_pci_id" {
  type        = string
  default     = null
  description = "PCI address of the GPU audio function (e.g., '0000:01:00.1'). Set null to skip audio passthrough."
}

variable "gpu_primary_display" {
  type        = bool
  default     = true
  description = "Mark GPU as primary VGA display (x_vga). Set false for headless / secondary GPU."
}

################################################################################
# Windows / cloudbase-init
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
# Gaming Software
################################################################################

variable "install_steam" {
  type        = bool
  description = "Install Steam via the setup script"
  default     = true
}

################################################################################
# Custom user-data override
################################################################################

variable "user_data" {
  type        = string
  description = "Raw cloudbase-init user-data string. If set, overrides the built-in setup.ps1 template."
  default     = null
}

################################################################################
# Tags
################################################################################

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the VM (converted to Proxmox tag list)"
  default     = {}
}
