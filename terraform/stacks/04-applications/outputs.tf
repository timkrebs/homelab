output "vault_url" {
  description = "URL for Vault UI"
  value       = "https://vault.${var.domain}"
}

output "grafana_url" {
  description = "URL for Grafana UI"
  value       = "https://grafana.${var.domain}"
}

output "prometheus_url" {
  description = "URL for Prometheus UI"
  value       = "https://prometheus.${var.domain}"
}

output "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}
