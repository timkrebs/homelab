terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.target_node
  vm_id     = var.vm_id

  clone {
    vm_id = var.clone
    full  = true
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.disk.storage
    size         = var.disk.size
    interface    = "scsi0"
  }

  network_device {
    bridge = var.network.bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.network.ip
        gateway = var.network.gateway
      }
    }

    user_account {
      username = var.cloud_init.user
      keys     = var.cloud_init.ssh_keys
    }

    datastore_id = var.disk.storage
  }

  agent {
    enabled = true
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}
