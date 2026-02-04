output "kubeconfig" {
  description = "Kubeconfig for the k3s cluster"
  value       = ssh_resource.kubeconfig.result
  sensitive   = true
}

output "control_plane_ip" {
  description = "IP address of the k3s control plane"
  value       = local.control_plane_ip
}

output "worker_ips" {
  description = "IP addresses of the k3s worker nodes"
  value       = local.worker_ips
}

output "k3s_version" {
  description = "Installed k3s version"
  value       = var.k3s_version
}
