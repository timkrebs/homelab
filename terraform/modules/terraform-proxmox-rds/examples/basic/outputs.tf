output "endpoint" {
  description = "Database connection endpoint"
  value       = module.db.endpoint
}

output "address" {
  description = "Database IP address"
  value       = module.db.address
}

output "port" {
  description = "Database port"
  value       = module.db.port
}

output "db_name" {
  description = "Database name"
  value       = module.db.db_name
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = module.db.connection_string
  sensitive   = true
}

output "ssh_connection" {
  description = "SSH connection for management"
  value       = module.db.ssh_connection
}
