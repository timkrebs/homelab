# -----------------------------------------------------------------------------
# K3s Kubernetes Cluster Outputs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VM Information
# -----------------------------------------------------------------------------

output "control_plane_vm_id" {
  description = "Control plane VM ID"
  value       = module.k3s_control_plane.vm_id
}

output "control_plane_ip" {
  description = "Control plane IP address"
  value       = var.control_plane_ip
}

output "worker_vm_ids" {
  description = "Worker node VM IDs"
  value       = { for k, v in module.k3s_workers : k => v.vm_id }
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = var.worker_ips
}

# -----------------------------------------------------------------------------
# Kubernetes Access
# -----------------------------------------------------------------------------

output "kubernetes_api_url" {
  description = "Kubernetes API server URL"
  value       = "https://${var.control_plane_ip}:6443"
}

output "kubernetes_api_dns" {
  description = "Kubernetes API server URL via DNS"
  value       = "https://k8s.${var.cloudflare_zone}:6443"
}

# -----------------------------------------------------------------------------
# DNS Records
# -----------------------------------------------------------------------------

output "control_plane_dns" {
  description = "Control plane DNS record"
  value       = "k8s-control-01.${var.cloudflare_zone}"
}

output "worker_dns" {
  description = "Worker node DNS records"
  value       = { for k, v in var.worker_ips : k => "${k}.${var.cloudflare_zone}" }
}

output "ingress_wildcard_dns" {
  description = "Ingress wildcard DNS pattern"
  value       = "*.k8s.${var.cloudflare_zone}"
}

# -----------------------------------------------------------------------------
# TLS Certificates
# -----------------------------------------------------------------------------

output "k3s_server_cert_expiry" {
  description = "K3s API server TLS certificate expiration"
  value       = vault_pki_secret_backend_cert.k3s_server.expiration
}

output "vault_ca_chain" {
  description = "Vault CA chain used for K3s TLS (PEM)"
  value       = vault_pki_secret_backend_cert.k3s_server.ca_chain
  sensitive   = true
}

# -----------------------------------------------------------------------------
# K3s Cluster Token
# -----------------------------------------------------------------------------

output "k3s_token" {
  description = "K3s cluster join token (stored in Vault at k3s/cluster-token)"
  value       = random_password.k3s_token.result
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Vault Integration (for 02-vault-infra Kubernetes auth)
# -----------------------------------------------------------------------------

output "kubernetes_auth_config" {
  description = "Values to set in 02-vault-infra/terraform.tfvars after cluster is ready"
  value = {
    enable_kubernetes_auth = true
    kubernetes_host        = "https://${var.control_plane_ip}:6443"
    kubernetes_ca_cert     = "# Retrieve with: ssh ${var.vm_user}@${var.control_plane_ip} sudo cat /var/lib/rancher/k3s/server/tls/server-ca.crt"
  }
}

# -----------------------------------------------------------------------------
# Post-Deployment Instructions
# -----------------------------------------------------------------------------

output "post_deployment_instructions" {
  description = "Steps to complete after Terraform apply"
  value       = <<-EOT
    ============================================================
    K3s KUBERNETES CLUSTER DEPLOYED
    ============================================================

    Cluster: 1 control plane + ${length(var.worker_ips)} workers
    K3s Version: ${var.k3s_version}
    API Server: https://${var.control_plane_ip}:6443
    DNS: k8s.${var.cloudflare_zone}

    1. WAIT FOR CLOUD-INIT TO COMPLETE (~5 minutes):
       ssh ${var.vm_user}@${var.control_plane_ip}
       sudo cloud-init status --wait

    2. VERIFY CLUSTER STATUS:
       ssh ${var.vm_user}@${var.control_plane_ip}
       sudo kubectl get nodes -o wide
       sudo kubectl get pods -A

    3. RETRIEVE KUBECONFIG:
       scp ${var.vm_user}@${var.control_plane_ip}:/etc/rancher/k3s/k3s.yaml ~/.kube/config
       # Then update the server address:
       sed -i '' 's|127.0.0.1|${var.control_plane_ip}|g' ~/.kube/config
       # Or use the DNS name:
       sed -i '' 's|127.0.0.1|k8s.${var.cloudflare_zone}|g' ~/.kube/config

    4. ENABLE VAULT KUBERNETES AUTH (02-vault-infra):
       Update terraform.tfvars with:
         enable_kubernetes_auth = true
         kubernetes_host        = "https://${var.control_plane_ip}:6443"
         kubernetes_ca_cert     = "<output of: ssh ${var.vm_user}@${var.control_plane_ip} sudo cat /var/lib/rancher/k3s/server/tls/server-ca.crt>"

    5. INSTALL CERT-MANAGER WITH VAULT ISSUER:
       helm repo add jetstack https://charts.jetstack.io
       helm install cert-manager jetstack/cert-manager \
         --namespace cert-manager \
         --set crds.enabled=true

    6. TLS CERTIFICATE INFO:
       API Server cert issued by: Vault PKI (${var.vault_pki_mount}/${var.vault_pki_role})
       Cert expiry: Check with 'terraform output k3s_server_cert_expiry'
       K3s token stored in Vault at: k3s/cluster-token

    ============================================================
  EOT
}
