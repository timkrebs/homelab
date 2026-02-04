output "traefik_ip" {
  description = "IP address of Traefik LoadBalancer"
  value       = var.traefik_ip
}

output "wildcard_cert_secret" {
  description = "Name of the wildcard certificate secret"
  value       = "wildcard-proxcloud-io-tls"
}

output "cluster_issuer" {
  description = "Name of the ClusterIssuer for Let's Encrypt"
  value       = "letsencrypt-prod"
}

output "metallb_ip_pool" {
  description = "MetalLB IP address pool name"
  value       = "default-pool"
}
