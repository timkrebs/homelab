################################################################################
# Instance Identity
################################################################################

variable "name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "vm_id" {
  type        = number
  default     = null
  description = "Proxmox VM ID (auto-assigned if not specified)"
}

################################################################################
# Instance Type (Proxmox sizing)
################################################################################

variable "instance_type" {
  type        = string
  description = "Instance type defining CPU and memory (e.g., 't3.small', 't3.medium', 't3.large', 't3.xlarge', 't3.2xlarge', 'custom')"
  default     = "t3.small"

  validation {
    condition     = contains(["t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge", "custom"], var.instance_type)
    error_message = "instance_type must be one of: t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge, custom."
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
  description = "Proxmox node to deploy the VM on"
}

variable "template_id" {
  type        = number
  description = "VM template ID to clone from (must have cloud-init and qemu-guest-agent)"
}

################################################################################
# Storage
################################################################################

variable "disk_size" {
  type        = number
  description = "Root disk size in GB"
  default     = 20
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool for the VM disk"
  default     = "local-lvm"
}

variable "snippets_storage" {
  type        = string
  description = "Proxmox storage for cloud-init snippets (must support 'snippets' content type)"
  default     = "local"
}

################################################################################
# Network
################################################################################

variable "ip_address" {
  type        = string
  description = "Static IP in CIDR notation (e.g., '192.168.1.50/24')"
}

variable "gateway" {
  type        = string
  description = "Network gateway IP address"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

################################################################################
# SSH / Cloud-Init
################################################################################

variable "ssh_user" {
  type        = string
  description = "Cloud-init user for SSH access"
  default     = "ubuntu"
}

variable "ssh_password" {
  type        = string
  description = "Cloud-init user password (enables password SSH login)"
  default     = null
  sensitive   = true
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for VM access"
}

variable "user_data" {
  type        = string
  description = "Cloud-init user data script (raw YAML). If provided, uploaded as a Proxmox snippet."
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
