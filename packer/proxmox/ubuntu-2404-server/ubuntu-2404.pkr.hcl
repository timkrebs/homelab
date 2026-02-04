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
  node                 = var.proxmox_node
  vm_id                = var.vm_id
  vm_name              = "ubuntu-2404-template"
  template_description = "Ubuntu 24.04 Server - Built ${timestamp()}"

  # VM OS Settings - Local ISO File
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
    disk_size    = "25G"
    storage_pool = var.storage_pool
    type         = "virtio"
  }

  # VM CPU Settings
  cores = 2

  # VM Memory Settings
  memory = 2048
  os     = "l26"

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  # PACKER Boot Commands
  # Uses GRUB command line to boot with autoinstall pointing to HTTP server
  boot              = "c"
  boot_wait         = "10s"
  boot_key_interval = "500ms"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]

  # PACKER Autoinstall Settings - HTTP server for cloud-init
  http_directory = "http"

  # SSH Settings
  ssh_username = "packer"
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"
  ssh_pty      = true
}

# Build Definition to create the VM Template
build {
  name    = "ubuntu-2404"
  sources = ["source.proxmox-iso.ubuntu-2404"]

  # HCP Packer Registry - credentials via HCP_CLIENT_ID, HCP_CLIENT_SECRET, HCP_PROJECT_ID env vars
  hcp_packer_registry {
    bucket_name = "ubuntu-2404-server"
    description = "Ubuntu 24.04 LTS Server for Kubernetes nodes"

    bucket_labels = {
      "os"      = "ubuntu"
      "version" = "24.04"
      "purpose" = "kubernetes"
    }

    build_labels = {
      "build-time"   = timestamp()
      "build-source" = basename(path.cwd)
    }
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox
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
      "sudo rm -f /etc/netplan/*.yaml",
      "sudo sync"
    ]
  }

  # Add cloud-init configuration for Proxmox
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }

  # Run additional setup scripts
  provisioner "shell" {
    scripts = [
      "scripts/setup.sh",
      "scripts/k8s-prereqs.sh",
      "scripts/cleanup.sh"
    ]
  }
}
