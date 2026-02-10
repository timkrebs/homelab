################################################################################
# Cloud-Init Snippet
################################################################################

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.target_node

  source_raw {
    data = templatefile("${path.module}/templates/postgres-cloud-init.yaml.tftpl", {
      identifier        = var.identifier
      engine_version    = var.engine_version
      port              = var.port
      listen_addresses  = var.listen_addresses
      vm_memory_mb      = local.vm_memory
      shared_buffers_mb = local.shared_buffers_mb
      allowed_cidrs     = var.allowed_cidrs
      db_name           = var.db_name
      db_username       = var.db_username
      db_password       = var.db_password
    })
    file_name = "${var.identifier}-cloud-init.yaml"
  }
}

################################################################################
# RDS-like Database Instance
################################################################################

resource "proxmox_virtual_environment_vm" "db_instance" {
  name      = var.identifier
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
    size         = var.allocated_storage
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

    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
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
