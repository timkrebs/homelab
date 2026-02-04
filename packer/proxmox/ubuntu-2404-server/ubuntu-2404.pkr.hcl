packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.0"
    }
  }
}

source "proxmox-iso" "ubuntu-2404" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify
  node                     = var.proxmox_node

  # VM Configuration
  vm_id                = var.vm_id
  vm_name              = "ubuntu-2404-template"
  template_description = "Ubuntu 24.04 Server - Built ${timestamp()}"

  # Boot ISO Configuration
  boot_iso {
    iso_file         = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
    iso_storage_pool = "local"
    unmount          = true
  }

  # Cloud-init autoinstall via CD-ROM (works from GitHub runners without HTTP connectivity)
  additional_iso_files {
    cd_files         = ["./http/meta-data", "./http/user-data"]
    cd_label         = "cidata"
    iso_storage_pool = "local"
    unmount          = true
  }

  # System
  qemu_agent      = true
  scsi_controller = "virtio-scsi-pci"

  # CPU & Memory
  cores  = 2
  memory = 2048

  # Disk
  disks {
    disk_size    = "20G"
    storage_pool = var.storage_pool
    type         = "scsi"
    format       = "raw"
  }

  # Network
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = false
  }

  # Cloud-Init for post-install
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  # Boot Configuration for Ubuntu 24.04 Live Server
  # The boot command:
  # 1. Waits for GRUB menu to appear
  # 2. Presses 'e' to edit the default entry
  # 3. Navigates to the 'linux' line (end of line)
  # 4. Adds 'autoinstall' kernel parameter with nocloud datasource pointing to CD-ROM
  # 5. Presses Ctrl+X to boot with modified parameters
  boot_command = [
    "<wait10><wait10><wait10>",
    "c<wait5>",
    "linux /casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/ ---<enter><wait5>",
    "initrd /casper/initrd<enter><wait5>",
    "boot<enter>"
  ]
  boot      = "order=ide2;scsi0;net0"
  boot_wait = "5s"

  # SSH Configuration
  ssh_username           = "packer"
  ssh_password           = var.ssh_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100
}

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

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = ["while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"]
  }

  # Run setup scripts
  provisioner "shell" {
    scripts = [
      "scripts/setup.sh",
      "scripts/k8s-prereqs.sh",
      "scripts/cleanup.sh"
    ]
  }
}
