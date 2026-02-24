################################################################################
# Windows 11 Gaming VM with Nvidia GPU Passthrough + Parsec
#
# Prerequisites on the Proxmox host (must be done before `terraform apply`):
#
# 1. Enable IOMMU in GRUB (/etc/default/grub):
#      GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
#    or for AMD:
#      GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
#    Then: update-grub && reboot
#
# 2. Load VFIO modules (/etc/modules):
#      vfio
#      vfio_iommu_type1
#      vfio_pci
#    Then: update-initramfs -u -k all && reboot
#
# 3. Blacklist the Nvidia driver on the Proxmox host so the GPU is
#    available for passthrough (/etc/modprobe.d/blacklist-nvidia.conf):
#      blacklist nouveau
#      blacklist nvidia*
#    Then: update-initramfs -u -k all && reboot
#
# 4. Find your GPU's PCI address:
#      lspci | grep -i nvidia
#    Example output:
#      01:00.0 VGA compatible controller: NVIDIA Tesla T4
#      01:00.1 Audio device: NVIDIA ...
#    Set gpu_pci_id     = "0000:01:00.0"
#    Set gpu_audio_pci_id = "0000:01:00.1"
#
# 5. Create a Windows 11 VM template in Proxmox:
#    - Machine: q35  |  BIOS: OVMF (UEFI)  |  vTPM 2.0
#    - Attach Windows 11 ISO + VirtIO drivers ISO (virtio-win)
#    - Install Windows 11
#    - Install VirtIO guest drivers (storage, network, balloon, qxl)
#    - Install QEMU Guest Agent
#    - Install cloudbase-init: https://cloudbase.it/cloudbase-init/
#      (configure NoCloud datasource for Proxmox)
#    - Sysprep: C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown
#    - Convert to template in Proxmox (right-click → Convert to Template)
#    - Note the template VM ID and set it as template_id below.
#
# References:
#   GPU passthrough: https://pve.proxmox.com/wiki/PCI_Passthrough
#   cloudbase-init:  https://cloudbase-init.readthedocs.io/en/latest/
################################################################################

module "gaming_vm" {
  source = "../modules/terraform-proxmox-gaming"

  # Identity
  name  = var.vm_name
  vm_id = var.vm_id

  # Sizing (see locals.tf in the module for available sizes)
  instance_type = var.instance_type

  # Proxmox target
  target_node = var.proxmox_node
  template_id = var.template_id

  # Storage
  disk_size    = var.disk_size
  storage_pool = var.storage_pool

  # Network
  ip_address     = var.ip_address
  gateway        = var.network_gateway
  network_bridge = var.network_bridge

  # Nvidia Tesla GPU passthrough
  gpu_pci_id          = var.gpu_pci_id
  gpu_audio_pci_id    = var.gpu_audio_pci_id
  gpu_primary_display = var.gpu_primary_display

  # Windows admin credentials
  admin_username = var.admin_username
  admin_password = var.admin_password

  # Gaming software
  install_steam = var.install_steam

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
    Role        = "gaming"
    GPU         = "nvidia-tesla"
  }
}
