output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.gaming.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.gaming.name
}

output "ip_address" {
  description = "VM IP address (CIDR)"
  value       = var.ip_address
}

output "ip_host" {
  description = "VM host IP (without prefix length)"
  value       = split("/", var.ip_address)[0]
}

output "rdp_connection" {
  description = "Windows RDP connection string (open in Remote Desktop on macOS)"
  value       = "rdp://${split("/", var.ip_address)[0]}"
}

output "parsec_instructions" {
  description = "Parsec setup instructions"
  value       = <<-EOT
    Parsec Remote Gaming Setup
    --------------------------
    1. RDP into the VM to complete initial Windows setup:
         ${split("/", var.ip_address)[0]}  (user: ${var.admin_username})
    2. Sign into Parsec on the gaming VM (https://parsec.app) with your account.
    3. Enable "Host" in Parsec settings → Host tab.
    4. On your Mac, open Parsec and connect to this machine.
    5. For Tesla GPU (headless): verify the Parsec Virtual Display is active
       under Display Settings — it appears as "Parsec Virtual Display Adapter".
  EOT
}
