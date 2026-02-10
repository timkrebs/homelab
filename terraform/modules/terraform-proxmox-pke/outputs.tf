output "cluster_name" {
  description = "The name of the K3s cluster"
  value       = var.cluster_name
}

output "control_plane_ips" {
  description = "Control plane node IP addresses"
  value       = [local.control_plane_ip]
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = [for name, w in local.workers : w.ip]
}

output "control_plane_vm_ids" {
  description = "Control plane Proxmox VM IDs"
  value       = [proxmox_virtual_environment_vm.control_plane.vm_id]
}

output "worker_vm_ids" {
  description = "Worker Proxmox VM IDs"
  value       = { for k, v in proxmox_virtual_environment_vm.workers : k => v.vm_id }
}

output "kubernetes_api_url" {
  description = "Kubernetes API server URL"
  value       = "https://${local.control_plane_ip}:6443"
}

output "k3s_token" {
  description = "K3s cluster join token"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "ssh_user" {
  description = "SSH user for accessing cluster nodes"
  value       = var.ssh_user
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from the control plane"
  value       = "scp ${var.ssh_user}@${local.control_plane_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig && sed -i '' 's|127.0.0.1|${local.control_plane_ip}|g' ./kubeconfig"
}
