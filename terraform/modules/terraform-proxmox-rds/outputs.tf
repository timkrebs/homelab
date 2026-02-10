output "db_instance_id" {
  description = "The Proxmox VM ID of the database instance"
  value       = proxmox_virtual_environment_vm.db_instance.vm_id
}

output "db_instance_name" {
  description = "The VM name of the database instance"
  value       = proxmox_virtual_environment_vm.db_instance.name
}

output "endpoint" {
  description = "The connection endpoint (address:port)"
  value       = "${local.db_address}:${var.port}"
}

output "address" {
  description = "The IP address of the database instance"
  value       = local.db_address
}

output "port" {
  description = "The port the database is listening on"
  value       = var.port
}

output "db_name" {
  description = "The name of the initial database"
  value       = var.db_name
}

output "db_username" {
  description = "The master username"
  value       = var.db_username
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.db_username}:${var.db_password}@${local.db_address}:${var.port}/${var.db_name}"
  sensitive   = true
}

output "ssh_connection" {
  description = "SSH connection string for management"
  value       = "${var.ssh_user}@${local.db_address}"
}
