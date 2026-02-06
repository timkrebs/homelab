# Note: Vault is now deployed via 05-vault stack on dedicated VMs
# See terraform/stacks/05-vault/ for Vault-related outputs

output "grafana_url" {
  description = "URL for Grafana UI"
  value       = "https://grafana.${var.domain}"
}

output "prometheus_url" {
  description = "URL for Prometheus UI"
  value       = "https://prometheus.${var.domain}"
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
