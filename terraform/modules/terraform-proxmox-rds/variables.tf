################################################################################
# Instance Identity
################################################################################

variable "identifier" {
  type        = string
  description = "Name of the database instance (used as VM name)"
}

variable "vm_id" {
  type        = number
  default     = null
  description = "Proxmox VM ID (auto-assigned if not specified)"
}

################################################################################
# Engine
################################################################################

variable "engine" {
  type        = string
  description = "Database engine"
  default     = "postgres"

  validation {
    condition     = contains(["postgres"], var.engine)
    error_message = "Engine must be one of: postgres."
  }
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL major version"
  default     = "16"

  validation {
    condition     = contains(["14", "15", "16", "17"], var.engine_version)
    error_message = "engine_version must be one of: 14, 15, 16, 17."
  }
}

################################################################################
# Instance Class (Proxmox sizing)
################################################################################

variable "instance_class" {
  type        = string
  description = "Instance class defining CPU and memory (e.g., 'db.t3.micro', 'db.t3.medium')"
  default     = "db.t3.micro"

  validation {
    condition     = contains(["db.t3.small", "db.t3.medium", "db.t3.large", "db.t3.xlarge", "db.t3.2xlarge", "custom"], var.instance_class)
    error_message = "instance_class must be one of: db.t3.small, db.t3.medium, db.t3.large, db.t3.xlarge, db.t3.2xlarge, custom."
  }
}

variable "custom_cores" {
  type        = number
  default     = null
  description = "CPU cores (only used when instance_class = 'custom')"
}

variable "custom_memory" {
  type        = number
  default     = null
  description = "Memory in MB (only used when instance_class = 'custom')"
}

################################################################################
# Storage
################################################################################

variable "allocated_storage" {
  type        = number
  description = "Disk size in GB for the database VM"
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
# Database
################################################################################

variable "db_name" {
  type        = string
  description = "Name of the initial database to create"
}

variable "db_username" {
  type        = string
  description = "Master username for the database"
}

variable "db_password" {
  type        = string
  description = "Master password for the database"
  sensitive   = true
}

variable "port" {
  type        = number
  description = "Port the database listens on"
  default     = 5432
}

variable "listen_addresses" {
  type        = string
  description = "PostgreSQL listen_addresses setting"
  default     = "*"
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to connect to the database (added to pg_hba.conf)"
  default     = ["0.0.0.0/0"]
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
# Network
################################################################################

variable "ip_address" {
  type        = string
  description = "Static IP in CIDR notation (e.g., '192.168.1.60/24')"
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

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for VM access"
}

################################################################################
# Tags
################################################################################

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the VM (converted to Proxmox tag list)"
  default     = {}
}
