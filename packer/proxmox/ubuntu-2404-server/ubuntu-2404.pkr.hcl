# Ubuntu 24.04 Server Template for Proxmox
# Based on working ubuntu-server-noble configuration

packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.0"
    }
  }
}

# Resource Definition for the VM Template
source "proxmox-iso" "ubuntu-2404" {
  # Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify

  # VM General Settings
  node                 = "${var.proxmox_node}"
  vm_id                = "${var.vm_id}"
  vm_name              = "ubuntu-2404-template"
  template_description = "Ubuntu 24.04 Server - Built ${timestamp()}"

  # VM OS Settings - Local ISO File
  # Use ide2 for boot ISO (standard CD-ROM location for SeaBIOS)
  boot_iso {
    type         = "scsi"
    iso_file     = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
    unmount      = true
    iso_checksum = "e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
  }

  # Cloud-init ISO for autoinstall (more reliable than HTTP for remote Proxmox)
  # Use ide3 to avoid conflict with boot ISO on ide2
  #additional_iso_files {
  #  cd_files         = ["./http/meta-data", "./http/user-data"]
  #  cd_label         = "cidata"
  #  iso_storage_pool = "local"
  #  unmount          = true
  #  device           = "ide3"
  #}

  # Boot order: d=CD-ROM first, c=hard disk second
  # Using legacy format for compatibility
  #boot = "dc"

  # VM System Settings
  qemu_agent = true


  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size    = "25G"
    storage_pool = "${local.disk_storage}"
    type         = "virtio"
  }

  # VM CPU Settings
  cores = "2"

  # VM Memory Settings
  memory = "2048"
  # VM OS Settings
  os = "l26"

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
  #communicator = "ssh"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]
  # Useful for debugging
  # Sometimes lag will require this
  boot_key_interval = "500ms"


  # PACKER Autoinstall Settings
  http_directory = "http"

  # (Optional) Bind IP Address and Port
  # http_bind_address       = "0.0.0.0"
  # http_port_min           = 8802
  # http_port_max           = 8802

  ssh_username = "${var.ssh_username}"
  ssh_password = "${var.ssh_password}"
  # - or -
  # (Option 2) Add your Private SSH KEY file here
  # ssh_private_key_file    = "~/.ssh/id_rsa"

  # Raise the timeout, when installation takes longer
  ssh_timeout = "30m"
  ssh_pty     = true
}

# Build Definition to create the VM Template
build {
  name    = "ubuntu-server-noble"
  sources = ["source.proxmox-iso.ubuntu-server-noble"]

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
      # WICHTIG: Alle Netplan und Cloud-Init Netzwerk-Configs komplett löschen
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/cloud/cloud.cfg.d/50-curtin-networking.cfg",
      "sudo rm -f /etc/netplan/*.yaml",
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
    inline = [
      "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
    ]
  }
}
