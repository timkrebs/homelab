################################################################################
# Server Cloud-Init Snippet
################################################################################

resource "proxmox_virtual_environment_file" "k3s_server_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/k3s-server-cloud-init.yaml.tftpl", {
      node_name          = local.control_plane_name
      node_ip            = local.control_plane_ip
      k3s_version        = var.k3s_version
      k3s_token          = random_password.k3s_token.result
      cluster_cidr       = var.cluster_cidr
      service_cidr       = var.service_cidr
      cluster_dns        = var.cluster_dns
      flannel_backend    = var.flannel_backend
      disable_components = var.disable_components
    })
    file_name = "${var.cluster_name}-server-cloud-init.yaml"
  }
}

################################################################################
# Agent Cloud-Init Snippets (one per worker)
################################################################################

resource "proxmox_virtual_environment_file" "k3s_agent_cloud_init" {
  for_each = local.workers

  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/k3s-agent-cloud-init.yaml.tftpl", {
      node_name   = each.key
      server_ip   = local.control_plane_ip
      k3s_version = var.k3s_version
      k3s_token   = random_password.k3s_token.result
    })
    file_name = "${var.cluster_name}-${each.key}-cloud-init.yaml"
  }
}
