variable "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "cluster_token" {
  description = "Kubernetes cluster authentication token"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Base domain for ingress hosts"
  type        = string
  default     = "proxcloud.io"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "local-path"
}

variable "vault_license" {
  description = "Vault Enterprise license (leave empty for OSS)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "0.27.0"
}

variable "vault_image_tag" {
  description = "Vault image tag"
  type        = string
  default     = "1.15.6"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "56.6.2"
}

variable "loki_version" {
  description = "Loki stack Helm chart version"
  type        = string
  default     = "2.10.0"
}
