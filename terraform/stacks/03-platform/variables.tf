variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

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

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS-01 challenge"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone" {
  description = "Cloudflare DNS zone (domain)"
  type        = string
  default     = "proxcloud.io"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB LoadBalancer services"
  type        = list(string)
  default     = ["10.10.2.100-10.10.2.200"]
}

variable "traefik_ip" {
  description = "Static IP for Traefik LoadBalancer"
  type        = string
  default     = "10.10.2.100"
}

variable "metallb_version" {
  description = "MetalLB Helm chart version"
  type        = string
  default     = "0.14.3"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "1.14.2"
}

variable "traefik_version" {
  description = "Traefik Helm chart version"
  type        = string
  default     = "26.0.0"
}
