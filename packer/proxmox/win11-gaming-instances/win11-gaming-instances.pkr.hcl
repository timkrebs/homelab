# Windows 11 Gaming Instance Templates for Proxmox
# ---
# Packer Template to create sized Windows 11 VM templates matching gaming instance tiers
# Mirrors the Ubuntu Noble instance pattern with g-type sizing (4c/8GB to 32c/64GB)
#
# Usage:
#   packer build -var "instance_type=g.medium" .
#   packer build -var "instance_type=g.large" .
#   packer build -var "instance_type=g.xlarge" .

packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variable Definitions
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "ssh_username" {
  type        = string
  description = "Admin username used for WinRM and the local Windows account"
}

variable "ssh_password" {
  type        = string
  sensitive   = true
  description = "Admin password used for WinRM and the local Windows account"
}

variable "virtio_win_iso" {
  type        = string
  default     = "local:iso/virtio-win.iso"
  description = "Proxmox storage path to the VirtIO drivers ISO (default ships with Proxmox)"
}

variable "instance_type" {
  type        = string
  description = "Gaming instance type (g.medium, g.large, g.xlarge, g.2xlarge)"
  default     = "g.medium"

  validation {
    condition     = contains(["g.medium", "g.large", "g.xlarge", "g.2xlarge"], var.instance_type)
    error_message = "Instance_type must be one of: g.medium, g.large, g.xlarge, g.2xlarge."
  }
}

locals {
  disk_storage = "local-lvm"

  # Gaming instance type mappings
  # Name         vCPUs  Memory   Disk
  # g.medium     4      8 GB     64 GB
  # g.large      8      16 GB    80 GB
  # g.xlarge     16     32 GB    120 GB
  # g.2xlarge    32     64 GB    200 GB
  instance_types = {
    "g.medium"  = { cores = 4,  memory = 8192,  disk = "64G",  vm_id = 9020 }
    "g.large"   = { cores = 8,  memory = 16384, disk = "80G",  vm_id = 9021 }
    "g.xlarge"  = { cores = 16, memory = 32768, disk = "120G", vm_id = 9022 }
    "g.2xlarge" = { cores = 32, memory = 65536, disk = "200G", vm_id = 9023 }
  }

  selected      = local.instance_types[var.instance_type]
  instance_slug = replace(var.instance_type, ".", "-")
}

# Resource Definition for the Windows 11 VM Template
source "proxmox-iso" "win11-gaming" {

  # Proxmox Connection Settings
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret

  # VM General Settings
  node                 = var.proxmox_node
  vm_id                = local.selected.vm_id
  vm_name              = "win11-gaming-${local.instance_slug}"
  template_description = "Windows 11 Gaming - ${var.instance_type} (${local.selected.cores} vCPU, ${local.selected.memory} MB RAM)"

  # VM System Settings — UEFI + TPM 2.0 required for Windows 11
  bios    = "ovmf"
  machine = "q35"

  efi_config {
    efi_storage_pool  = local.disk_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  tpm_config {
    tpm_storage_pool = local.disk_storage
    tpm_version      = "v2.0"
  }

  # QEMU guest agent (installed via VirtIO guest tools in setup.ps1)
  qemu_agent = true

  # Windows 11 Installation ISO
  boot_iso {
    type     = "sata"
    iso_file = "local:iso/Win11_25H2_English_x64.iso"
    unmount  = true
  }

  # VirtIO Drivers ISO — needed for disk driver injection in WinPE and guest tools
  additional_iso_files {
    type     = "sata"
    iso_file = var.virtio_win_iso
    unmount  = true
  }

  # Auto-generated CD containing the unattended answer file
  # Windows Setup automatically detects Autounattend.xml on any mounted drive
  additional_iso_files {
    type     = "sata"
    cd_content = {
      "Autounattend.xml" = templatefile("${path.root}/files/Autounattend.xml.pkrtpl.hcl", {
        winrm_username = var.ssh_username
        winrm_password = var.ssh_password
      })
    }
    cd_label = "AUTOUNATTEND"
    unmount  = false
  }

  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size    = local.selected.disk
    storage_pool = local.disk_storage
    type         = "virtio"
  }

  # VM CPU Settings
  cores = local.selected.cores

  # VM Memory Settings
  memory = local.selected.memory

  # VM Network Settings
  # e1000 uses the built-in Windows driver — no VirtIO driver needed for WinRM connectivity.
  # VirtIO network drivers are installed via setup.ps1 so clones can switch to virtio later.
  network_adapters {
    model    = "e1000"
    bridge   = "vmbr0"
    firewall = "false"
  }

  # WinRM Communicator (replaces SSH used in the Ubuntu template)
  communicator   = "winrm"
  winrm_username = var.ssh_username
  winrm_password = var.ssh_password
  winrm_timeout  = "2h"
  winrm_insecure = true
  winrm_use_ssl  = false

  # Boot Settings
  boot_wait = "5s"

  # Sysprep shutdown — generalises the image so each clone gets a unique SID/hostname
  shutdown_command = "C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /quiet"
  shutdown_timeout = "30m"
}

# Build Definition to create the VM Template
build {

  name    = "win11-gaming-${local.instance_slug}"
  sources = ["source.proxmox-iso.win11-gaming"]

  # Install VirtIO guest tools, enable RDP, configure power plan, then sysprep
  provisioner "powershell" {
    script = "${path.root}/files/setup.ps1"
  }
}
