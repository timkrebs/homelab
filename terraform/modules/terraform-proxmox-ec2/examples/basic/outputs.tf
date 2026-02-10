output "instance_id" {
  description = "The Proxmox VM ID"
  value       = module.ec2_instance.instance_id
}

output "private_ip" {
  description = "The private IP of the instance"
  value       = module.ec2_instance.private_ip
}

output "ssh_connection" {
  description = "SSH connection string"
  value       = module.ec2_instance.ssh_connection
}
