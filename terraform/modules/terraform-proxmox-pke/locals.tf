locals {
  # AWS EC2 t3 instance type mappings
  # Name         vCPUs  Memory (GiB)
  # t3.small     2      2.0
  # t3.medium    2      4.0
  # t3.large     2      8.0
  # t3.xlarge    4      16.0
  # t3.2xlarge   8      32.0
  instance_types = {
    "t3.small"   = { cores = 2, memory = 2048 }
    "t3.medium"  = { cores = 2, memory = 4096 }
    "t3.large"   = { cores = 2, memory = 8192 }
    "t3.xlarge"  = { cores = 4, memory = 16384 }
    "t3.2xlarge" = { cores = 8, memory = 32768 }
  }

  # Resolved sizing
  control_plane_sizing = local.instance_types[var.control_plane_instance_type]
  worker_sizing        = local.instance_types[var.worker_instance_type]

  # Convert map tags to list format
  base_tags = ["kubernetes", "k3s", var.cluster_name, var.environment]
  user_tags = [for k, v in var.tags : "${lower(k)}-${lower(v)}"]
  all_tags  = concat(local.base_tags, local.user_tags)

  # Control plane node
  control_plane_name = "${var.cluster_name}-control-01"
  control_plane_ip   = split("/", var.control_plane_ips[0])[0]

  # Worker nodes map: name => { ip_cidr, ip, index }
  workers = {
    for idx in range(var.worker_count) :
    "${var.cluster_name}-worker-${format("%02d", idx + 1)}" => {
      ip_cidr = var.worker_ips[idx]
      ip      = split("/", var.worker_ips[idx])[0]
      index   = idx
    }
  }
}
