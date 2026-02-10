output "instance_id" {
  description = "The Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.instance.vm_id
}

output "instance_name" {
  description = "The VM name"
  value       = proxmox_virtual_environment_vm.instance.name
}

output "private_ip" {
  description = "The private IP address of the instance"
  value       = split("/", var.ip_address)[0]
}

output "mac_address" {
  description = "The MAC address of the instance"
  value       = proxmox_virtual_environment_vm.instance.network_device[0].mac_address
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = "${var.ssh_user}@${split("/", var.ip_address)[0]}"
}
