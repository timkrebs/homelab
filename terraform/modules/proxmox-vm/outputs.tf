output "vm_id" {
  description = "The VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "The VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "ip_address" {
  description = "The VM IP address"
  value       = split("/", var.network.ip)[0]
}

output "mac_address" {
  description = "The VM MAC address"
  value       = proxmox_virtual_environment_vm.vm.network_device[0].mac_address
}
