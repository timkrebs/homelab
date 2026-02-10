################################################################################
# Cloud-Init User Data Snippet (optional)
################################################################################

resource "proxmox_virtual_environment_file" "user_data" {
  count = var.user_data != null ? 1 : 0

  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.target_node

  source_raw {
    data      = var.user_data
    file_name = "${var.name}-cloud-init.yaml"
  }
}

################################################################################
# EC2-like Instance
################################################################################

resource "proxmox_virtual_environment_vm" "instance" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vm_id

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = local.vm_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = local.vm_memory
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size
    interface    = "virtio0"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = var.ssh_user
      keys     = var.ssh_public_keys
    }

    user_data_file_id = var.user_data != null ? proxmox_virtual_environment_file.user_data[0].id : null
    datastore_id      = var.storage_pool
  }

  agent {
    enabled = true
  }

  tags = local.tag_list

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}
