################################################################################
# K3s Cluster Token
################################################################################

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

################################################################################
# Control Plane
################################################################################

resource "proxmox_virtual_environment_vm" "control_plane" {
  name      = local.control_plane_name
  node_name = var.proxmox_node

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = local.control_plane_sizing.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = local.control_plane_sizing.memory
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.control_plane_disk_size
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
        address = var.control_plane_ips[0]
        gateway = var.network_gateway
      }
    }

    user_account {
      username = var.ssh_user
      keys     = var.ssh_public_keys
    }

    user_data_file_id = proxmox_virtual_environment_file.k3s_server_cloud_init.id
    datastore_id      = var.storage_pool
  }

  agent {
    enabled = true
  }

  tags = concat(local.all_tags, ["control-plane"])

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }
}

################################################################################
# Worker Nodes
################################################################################

resource "proxmox_virtual_environment_vm" "workers" {
  for_each = local.workers

  name      = each.key
  node_name = var.proxmox_node

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = local.worker_sizing.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = local.worker_sizing.memory
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.worker_disk_size
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
        address = each.value.ip_cidr
        gateway = var.network_gateway
      }
    }

    user_account {
      username = var.ssh_user
      keys     = var.ssh_public_keys
    }

    user_data_file_id = proxmox_virtual_environment_file.k3s_agent_cloud_init[each.key].id
    datastore_id      = var.storage_pool
  }

  agent {
    enabled = true
  }

  tags = concat(local.all_tags, ["worker"])

  lifecycle {
    ignore_changes = [
      initialization,
    ]
  }

  depends_on = [proxmox_virtual_environment_vm.control_plane]
}
