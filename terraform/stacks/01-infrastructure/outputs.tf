output "control_plane_ip" {
  description = "Control plane node IP address"
  value       = module.k8s_control_plane.ip_address
}

output "control_plane_id" {
  description = "Control plane VM ID"
  value       = module.k8s_control_plane.vm_id
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = { for k, v in module.k8s_workers : k => v.ip_address }
}

output "worker_ids" {
  description = "Worker VM IDs"
  value       = { for k, v in module.k8s_workers : k => v.vm_id }
}
