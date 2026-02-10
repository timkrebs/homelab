output "kubernetes_api_url" {
  description = "Kubernetes API server URL"
  value       = module.kubernetes.kubernetes_api_url
}

output "control_plane_ips" {
  description = "Control plane node IPs"
  value       = module.kubernetes.control_plane_ips
}

output "worker_ips" {
  description = "Worker node IPs"
  value       = module.kubernetes.worker_ips
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = module.kubernetes.kubeconfig_command
}
