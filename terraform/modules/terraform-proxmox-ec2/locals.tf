locals {
  # AWS EC2 t3 instance type mappings
  # Name         vCPUs  Memory (GiB)
  # t3.nano      2      0.5
  # t3.micro     2      1.0
  # t3.small     2      2.0
  # t3.medium    2      4.0
  # t3.large     2      8.0
  # t3.xlarge    4      16.0
  # t3.2xlarge   8      32.0
  instance_types = {
    "t3.nano"    = { cores = 2, memory = 512 }
    "t3.micro"   = { cores = 2, memory = 1024 }
    "t3.small"   = { cores = 2, memory = 2048 }
    "t3.medium"  = { cores = 2, memory = 4096 }
    "t3.large"   = { cores = 2, memory = 8192 }
    "t3.xlarge"  = { cores = 4, memory = 16384 }
    "t3.2xlarge" = { cores = 8, memory = 32768 }
    "custom"     = { cores = var.custom_cores, memory = var.custom_memory }
  }

  selected  = local.instance_types[var.instance_type]
  vm_cores  = local.selected.cores
  vm_memory = local.selected.memory

  # Convert map tags to list format for proxmox-vm submodule
  tag_list = [for k, v in var.tags : "${lower(k)}-${lower(v)}"]
}
