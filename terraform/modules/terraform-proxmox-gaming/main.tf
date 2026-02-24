################################################################################
# cloudbase-init user-data snippet
################################################################################

resource "proxmox_virtual_environment_file" "setup_script" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.target_node

  source_raw {
    data      = local.setup_script
    file_name = "${var.name}-setup.ps1"
  }
}

################################################################################
# Gaming VM
################################################################################

resource "proxmox_virtual_environment_vm" "gaming" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vm_id

  description = "Windows 11 gaming VM — ${var.instance_type} | GPU passthrough | Parsec"

  # q35 is required for PCIe passthrough (GPU)
  machine = "q35"

  # UEFI required for Windows 11
  bios = "ovmf"

  # EFI disk (required by OVMF)
  efi_disk {
    datastore_id = var.storage_pool
    file_format  = "raw"
    type         = "4m"
  }

  # TPM 2.0 required for Windows 11
  tpm_state {
    datastore_id = var.storage_pool
    version      = "v2.0"
  }

  clone {
    vm_id = var.template_id
    full  = true
  }

  # Host CPU passthrough gives the best gaming performance.
  # Hyper-V enlightenments improve Windows scheduling & latency.
  cpu {
    cores = local.vm_cores
    type  = "host"
    flags = [
      "+hv-vendor-id", # Expose Hyper-V vendor ID (required for some Nvidia drivers in VMs)
      "+hv-stimer",    # Hyper-V synthetic timer
      "+hv-time",      # Hyper-V reference time counter
      "+hv-vapic",     # Hyper-V virtual APIC
      "+hv-reset",     # Hyper-V reset
    ]
  }

  memory {
    dedicated = local.vm_memory
  }

  # SCSI disk with iothread for best Windows storage performance
  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "win11"
  }

  # QEMU Guest Agent (must be installed in the Windows template)
  agent {
    enabled = true
  }

  # GPU passthrough — iterates over primary GPU graphics + optional audio function
  dynamic "hostpci" {
    for_each = local.hostpci_map
    content {
      device = hostpci.value.device
      id     = hostpci.value.id
      pcie   = true
      x_vga  = hostpci.value.x_vga
    }
  }

  # Virtual audio device for Parsec audio streaming
  audio_device {
    device  = "ich9-intel-hda"
    driver  = "spice"
    enabled = true
  }

  # cloudbase-init drives IP config and runs the setup PowerShell script
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = var.admin_username
      password = var.admin_password
    }

    user_data_file_id = proxmox_virtual_environment_file.setup_script.id
    datastore_id      = var.storage_pool
  }

  tags = local.tag_list

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}
