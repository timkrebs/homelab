terraform {
  required_version = ">= 1.13.0"

  cloud {
    organization = "tim-krebs-org"

    workspaces {
      name    = "homelab-applications"
      project = "proxmox-homelab"
    }
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# Reference outputs from previous stacks via Terraform Cloud
data "terraform_remote_state" "kubernetes" {
  backend = "remote"

  config = {
    organization = "tim-krebs-org"
    workspaces = {
      name = "homelab-kubernetes"
    }
  }
}

data "terraform_remote_state" "platform" {
  backend = "remote"

  config = {
    organization = "tim-krebs-org"
    workspaces = {
      name = "homelab-platform"
    }
  }
}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.kubernetes.outputs.control_plane_ip}:6443"
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = var.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.terraform_remote_state.kubernetes.outputs.control_plane_ip}:6443"
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = var.cluster_token
  }
}

locals {
  cluster_issuer = data.terraform_remote_state.platform.outputs.cluster_issuer
}

# Note: Vault Enterprise is now deployed on dedicated VMs via 05-vault stack
# See terraform/stacks/05-vault/ for the Vault HA cluster configuration

# Monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/name" = "monitoring"
    }
  }
}

# Prometheus Stack (includes Grafana, Prometheus, Alertmanager)
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.prometheus_stack_version

  values = [
    yamlencode({
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          hosts            = ["grafana.${var.domain}"]
          tls = [{
            secretName = "grafana-tls"
            hosts      = ["grafana.${var.domain}"]
          }]
          annotations = {
            "cert-manager.io/cluster-issuer" = local.cluster_issuer
          }
        }
        persistence = {
          enabled          = true
          size             = "10Gi"
          storageClassName = var.storage_class
        }
      }
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
        }
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          hosts            = ["prometheus.${var.domain}"]
          tls = [{
            secretName = "prometheus-tls"
            hosts      = ["prometheus.${var.domain}"]
          }]
          annotations = {
            "cert-manager.io/cluster-issuer" = local.cluster_issuer
          }
        }
      }
      alertmanager = {
        enabled = true
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }
    })
  ]
}

# Loki for log aggregation
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.loki_version

  values = [
    yamlencode({
      loki = {
        enabled = true
        persistence = {
          enabled          = true
          size             = "20Gi"
          storageClassName = var.storage_class
        }
      }
      promtail = {
        enabled = true
      }
      grafana = {
        enabled = false # Already deployed via kube-prometheus-stack
      }
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}
