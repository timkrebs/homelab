locals {
  # AWS RDS db.t3 instance class mappings
  # Name            vCPUs  Memory (GiB)
  # db.t3.small     2      2.0
  # db.t3.medium    2      4.0
  # db.t3.large     2      8.0
  # db.t3.xlarge    4      16.0
  # db.t3.2xlarge   8      32.0
  instance_types = {
    "db.t3.small"   = { cores = 2, memory = 2048 }
    "db.t3.medium"  = { cores = 2, memory = 4096 }
    "db.t3.large"   = { cores = 2, memory = 8192 }
    "db.t3.xlarge"  = { cores = 4, memory = 16384 }
    "db.t3.2xlarge" = { cores = 8, memory = 32768 }
    "custom"        = { cores = var.custom_cores, memory = var.custom_memory }
  }

  selected  = local.instance_types[var.instance_class]
  vm_cores  = local.selected.cores
  vm_memory = local.selected.memory

  # PostgreSQL shared_buffers = 25% of total memory
  shared_buffers_mb = floor(local.vm_memory / 4)

  # IP without CIDR prefix
  db_address = split("/", var.ip_address)[0]

  # Convert map tags to list format for Proxmox
  tag_list = [for k, v in var.tags : "${lower(k)}-${lower(v)}"]
}
