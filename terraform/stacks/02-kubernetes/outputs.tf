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

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  value       = try(yamldecode(ssh_resource.kubeconfig.result).clusters[0].cluster["certificate-authority-data"], "")
  sensitive   = true
}

output "cluster_token" {
  description = "Cluster authentication token (service account token)"
  value       = try(yamldecode(ssh_resource.kubeconfig.result).users[0].user["token"], "")
  sensitive   = true
}
