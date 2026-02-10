# Ubuntu Server Noble (24.04.x) - EC2-like Instance Type Templates
# ---
# Packer Template to create sized VM templates matching AWS EC2 t3 instance types
#
# Usage:
#   packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.micro" .
#   packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.medium" .
#   packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.xlarge" .

# Variable Definitions
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "ssh_username" {
  type = string
}

variable "ssh_password" {
  type      = string
  sensitive = true
}

variable "instance_type" {
  type        = string
  description = "EC2-like instance type (t3.nano, t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge)"
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.nano", "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.instance_type)
    error_message = "Instance_type must be one of: t3.nano, t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge."
  }
}

locals {
  disk_storage = "local-lvm"

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
    "t3.nano"    = { cores = 2, memory = 512,   disk = "10G", vm_id = 9010 }
    "t3.micro"   = { cores = 2, memory = 1024,  disk = "15G", vm_id = 9011 }
    "t3.small"   = { cores = 2, memory = 2048,  disk = "20G", vm_id = 9012 }
    "t3.medium"  = { cores = 2, memory = 4096,  disk = "25G", vm_id = 9013 }
    "t3.large"   = { cores = 2, memory = 8192,  disk = "30G", vm_id = 9014 }
    "t3.xlarge"  = { cores = 4, memory = 16384, disk = "50G", vm_id = 9015 }
    "t3.2xlarge" = { cores = 8, memory = 32768, disk = "80G", vm_id = 9016 }
  }

  selected      = local.instance_types[var.instance_type]
  instance_slug = replace(var.instance_type, ".", "-")
}

# Resource Definition for the VM Template
source "proxmox-iso" "ubuntu-noble-instance" {

  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"

  # VM General Settings
  node                 = "${var.proxmox_node}"
  vm_id                = "${local.selected.vm_id}"
  vm_name              = "ubuntu-noble-${local.instance_slug}"
  template_description = "Ubuntu Server Noble - ${var.instance_type} (${local.selected.cores} vCPU, ${local.selected.memory} MB RAM)"

  # VM OS Settings
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
    unmount      = true
    iso_checksum = "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
  }

  # VM System Settings
  qemu_agent = true

  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size    = "${local.selected.disk}"
    storage_pool = "${local.disk_storage}"
    type         = "virtio"
  }

  # VM CPU Settings
  cores = "${local.selected.cores}"

  # VM Memory Settings
  memory = "${local.selected.memory}"

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  # VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "${local.disk_storage}"

  # PACKER Boot Commands
  boot      = "c"
  boot_wait = "10s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  boot_key_interval = "500ms"

  # PACKER Autoinstall Settings
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data.pkrtpl.hcl", {
      ssh_username = var.ssh_username
      ssh_password = var.ssh_password
    })
    "/meta-data" = ""
  }

  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"

  # Raise the timeout, when installation takes longer
  ssh_timeout = "30m"
}

# Build Definition to create the VM Template
build {

  name    = "ubuntu-noble-${local.instance_slug}"
  sources = ["source.proxmox-iso.ubuntu-noble-instance"]

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo sync"
    ]
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }
}
