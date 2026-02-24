output "vm_id" {
  description = "Proxmox VM ID"
  value       = module.gaming_vm.vm_id
}

output "vm_name" {
  description = "VM name"
  value       = module.gaming_vm.vm_name
}

output "ip_address" {
  description = "VM IP address"
  value       = module.gaming_vm.ip_host
}

output "rdp_connection" {
  description = "macOS Remote Desktop connection URI"
  value       = module.gaming_vm.rdp_connection
}

output "parsec_instructions" {
  description = "Parsec setup steps"
  value       = module.gaming_vm.parsec_instructions
}
