variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "target_node" {
  type        = string
  description = "Proxmox node to deploy on"
}

variable "vm_id" {
  type        = number
  default     = null
  description = "VM ID (auto-assigned if not specified)"
}

variable "clone" {
  type        = string
  description = "Template VM ID or name to clone from"
}

variable "cores" {
  type        = number
  default     = 2
  description = "Number of CPU cores"
}

variable "memory" {
  type        = number
  default     = 2048
  description = "Memory in MB"
}

variable "disk" {
  type = object({
    size    = number
    storage = string
  })
  default = {
    size    = 20
    storage = "local-lvm"
  }
  description = "Disk configuration"
}

variable "network" {
  type = object({
    bridge  = string
    ip      = string
    gateway = string
  })
  description = "Network configuration"
}

variable "cloud_init" {
  type = object({
    user     = string
    ssh_keys = list(string)
  })
  description = "Cloud-init configuration"
}

variable "tags" {
  type        = list(string)
  default     = []
  description = "Tags for the VM"
}
