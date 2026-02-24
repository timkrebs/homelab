locals {
  # Gaming-optimized instance sizes
  # Name         vCPUs  Memory (GiB)
  # g.medium     4      8.0
  # g.large      8      16.0
  # g.xlarge     16     32.0
  # g.2xlarge    32     64.0
  instance_types = {
    "g.medium"  = { cores = 4, memory = 8192 }
    "g.large"   = { cores = 8, memory = 16384 }
    "g.xlarge"  = { cores = 16, memory = 32768 }
    "g.2xlarge" = { cores = 32, memory = 65536 }
    "custom"    = { cores = var.custom_cores, memory = var.custom_memory }
  }

  selected  = local.instance_types[var.instance_type]
  vm_cores  = local.selected.cores
  vm_memory = local.selected.memory

  # Convert map tags to list format for Proxmox
  tag_list = [for k, v in var.tags : "${lower(k)}-${lower(v)}"]

  # Build PCI passthrough device list:
  #   index 0 = primary GPU graphics function (x_vga = true)
  #   index 1 = GPU audio function (optional)
  hostpci_raw = compact([var.gpu_pci_id, var.gpu_audio_pci_id])
  hostpci_map = {
    for i, id in local.hostpci_raw : i => {
      device = "hostpci${i}"
      id     = id
      x_vga  = i == 0 ? var.gpu_primary_display : false
    }
  }

  # Rendered setup script (cloudbase-init PowerShell user-data)
  setup_script = var.user_data != null ? var.user_data : templatefile(
    "${path.module}/templates/setup.ps1.tftpl",
    {
      computer_name  = var.name
      admin_username = var.admin_username
      admin_password = var.admin_password
      install_steam  = var.install_steam
    }
  )
}
