output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.pke.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server URL"
  value       = module.pke.kubernetes_api_url
}

output "control_plane_ips" {
  description = "Control plane node IP addresses"
  value       = module.pke.control_plane_ips
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = module.pke.worker_ips
}

output "ssh_user" {
  description = "SSH user for accessing cluster nodes"
  value       = module.pke.ssh_user
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from the control plane"
  value       = module.pke.kubeconfig_command
}
