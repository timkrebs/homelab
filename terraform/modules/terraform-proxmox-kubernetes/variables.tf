################################################################################
# Cluster Identity
################################################################################

variable "cluster_name" {
  type        = string
  description = "Name prefix for all cluster resources (e.g., 'my-k3s-cluster')"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.cluster_name))
    error_message = "cluster_name must be lowercase alphanumeric with hyphens, 2-31 chars, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Environment tag (e.g., dev, staging, prod)"
  default     = "dev"
}

################################################################################
# Proxmox Target
################################################################################

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to deploy VMs on"
}

variable "template_id" {
  type        = number
  description = "VM template ID to clone from (must have cloud-init and qemu-guest-agent)"
}

variable "storage_pool" {
  type        = string
  description = "Proxmox storage pool for VM disks"
  default     = "local-lvm"
}

variable "snippets_storage" {
  type        = string
  description = "Proxmox storage for cloud-init snippets (must support 'snippets' content type)"
  default     = "local"
}

################################################################################
# Control Plane Nodes
################################################################################

variable "control_plane_count" {
  type        = number
  description = "Number of control plane nodes (only 1 supported in this version)"
  default     = 1

  validation {
    condition     = var.control_plane_count == 1
    error_message = "Only single control plane (count=1) is supported in this module version."
  }
}

variable "control_plane_instance_type" {
  type        = string
  description = "Instance type for control plane nodes (t3.nano, t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge)"
  default     = "t3.large"

  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.control_plane_instance_type)
    error_message = "control_plane_instance_type must be a valid t3 instance type."
  }
}

variable "control_plane_disk_size" {
  type        = number
  description = "Disk size in GB for each control plane node"
  default     = 50
}

variable "control_plane_ips" {
  type        = list(string)
  description = "List of static IPs in CIDR notation for control plane nodes (e.g., ['192.168.1.100/24'])"
}

################################################################################
# Worker Nodes
################################################################################

variable "worker_count" {
  type        = number
  description = "Number of worker nodes"
  default     = 2

  validation {
    condition     = var.worker_count >= 0
    error_message = "worker_count must be 0 or greater."
  }
}

variable "worker_instance_type" {
  type        = string
  description = "Instance type for worker nodes (t3.nano, t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge)"
  default     = "t3.xlarge"

  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.worker_instance_type)
    error_message = "worker_instance_type must be a valid t3 instance type."
  }
}

variable "worker_disk_size" {
  type        = number
  description = "Disk size in GB for each worker node"
  default     = 100
}

variable "worker_ips" {
  type        = list(string)
  description = "List of static IPs in CIDR notation for worker nodes (e.g., ['192.168.1.101/24', '192.168.1.102/24'])"
}

################################################################################
# Network
################################################################################

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "network_gateway" {
  type        = string
  description = "Network gateway IP address"
}

################################################################################
# SSH Access
################################################################################

variable "ssh_user" {
  type        = string
  description = "Cloud-init user for VM access"
  default     = "ubuntu"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys for VM access"
}

################################################################################
# K3s Configuration
################################################################################

variable "k3s_version" {
  type        = string
  description = "K3s version to install (e.g., 'v1.31.4+k3s1')"
  default     = "v1.31.4+k3s1"
}

variable "cluster_cidr" {
  type        = string
  description = "CIDR range for the pod network"
  default     = "10.42.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "CIDR range for the service network"
  default     = "10.43.0.0/16"
}

variable "cluster_dns" {
  type        = string
  description = "Cluster DNS service IP (must be within service_cidr)"
  default     = "10.43.0.10"
}

variable "disable_components" {
  type        = list(string)
  description = "K3s components to disable (e.g., traefik, servicelb)"
  default     = ["traefik", "servicelb"]
}

variable "flannel_backend" {
  type        = string
  description = "Flannel CNI backend type"
  default     = "vxlan"
}

################################################################################
# Tags
################################################################################

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources (converted to Proxmox tag list)"
  default     = {}
}
