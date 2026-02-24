# =============================================================================
# terraform.tfvars — gaming-vm
# Copy this file, fill in your values, and keep it out of version control.
# Add terraform.tfvars to your .gitignore.
# =============================================================================

# --- Proxmox connection ---
proxmox_api_url          = "https://192.168.1.10:8006/api2/json"
proxmox_api_token        = "root@pam!terraform"
proxmox_api_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
ssh_private_key          = <<-EOT
  -----BEGIN OPENSSH PRIVATE KEY-----
  <paste your Proxmox host SSH private key here>
  -----END OPENSSH PRIVATE KEY-----
EOT

# --- VM identity ---
vm_name      = "gaming-vm"
# vm_id      = 200          # uncomment to pin the VM ID
proxmox_node = "pve01"      # must be the node where the Nvidia Tesla is installed
template_id  = 9020         # your sysprepped Windows 11 template VM ID

# --- Sizing ---
# g.medium  = 4c / 8GB  | g.large = 8c / 16GB
# g.xlarge  = 16c / 32GB | g.2xlarge = 32c / 64GB
instance_type = "g.large"

# --- Storage ---
disk_size    = 256           # GB — increase if you install many games
storage_pool = "local-lvm"

# --- Network ---
ip_address      = "192.168.1.200/24"
network_gateway = "192.168.1.1"
network_bridge  = "vmbr0"

# --- GPU passthrough ---
# Run `lspci | grep -i nvidia` on the Proxmox host to find these.
# Example:
#   01:00.0 VGA compatible controller: NVIDIA Corporation TU104GL [Tesla T4]
#   01:00.1 Audio device: NVIDIA Corporation TU104 HD Audio Controller
gpu_pci_id          = "0000:01:00.0"
gpu_audio_pci_id    = "0000:01:00.1"   # set to null to skip audio passthrough
gpu_primary_display = true              # set false if GPU has no display output (pure compute)

# --- Windows credentials ---
admin_username = "gamer"
admin_password = "ChangeMe123!"        # change before apply

# --- Gaming software ---
install_steam = true
