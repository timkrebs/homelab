terraform {
  required_version = ">= 1.5.0"

  # Terraform Cloud backend - organization set via TF_CLOUD_ORGANIZATION env var
  cloud {
    workspaces {
      name = "homelab-applications"
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
    organization = var.tfc_organization
    workspaces = {
      name = "homelab-kubernetes"
    }
  }
}

data "terraform_remote_state" "platform" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
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

# Vault namespace
resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault-system"
    labels = {
      "app.kubernetes.io/name" = "vault"
    }
  }
}

# Vault Enterprise License Secret (if you have one)
resource "kubernetes_secret" "vault_license" {
  count = var.vault_license != "" ? 1 : 0

  metadata {
    name      = "vault-license"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }

  data = {
    license = var.vault_license
  }
}

# Vault Enterprise
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.metadata[0].name
  version    = var.vault_version

  values = [
    yamlencode({
      global = {
        enabled    = true
        tlsDisable = false
      }
      injector = {
        enabled = true
      }
      server = {
        image = {
          repository = var.vault_license != "" ? "hashicorp/vault-enterprise" : "hashicorp/vault"
          tag        = var.vault_image_tag
        }
        enterpriseLicense = var.vault_license != "" ? {
          secretName = "vault-license"
          secretKey  = "license"
        } : null
        resources = {
          requests = {
            memory = "256Mi"
            cpu    = "250m"
          }
          limits = {
            memory = "512Mi"
            cpu    = "500m"
          }
        }
        ha = {
          enabled  = true
          replicas = 3
          raft = {
            enabled   = true
            setNodeId = true
            config    = <<-EOT
              ui = true

              listener "tcp" {
                tls_disable = 1
                address = "[::]:8200"
                cluster_address = "[::]:8201"
              }

              storage "raft" {
                path = "/vault/data"
                retry_join {
                  leader_api_addr = "http://vault-0.vault-internal:8200"
                }
                retry_join {
                  leader_api_addr = "http://vault-1.vault-internal:8200"
                }
                retry_join {
                  leader_api_addr = "http://vault-2.vault-internal:8200"
                }
              }

              service_registration "kubernetes" {}
            EOT
          }
        }
        dataStorage = {
          enabled      = true
          size         = "10Gi"
          storageClass = var.storage_class
        }
        auditStorage = {
          enabled      = true
          size         = "5Gi"
          storageClass = var.storage_class
        }
      }
      ui = {
        enabled     = true
        serviceType = "ClusterIP"
      }
    })
  ]
}

# Vault Ingress
resource "kubernetes_ingress_v1" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"           = local.cluster_issuer
      "traefik.ingress.kubernetes.io/router.tls" = "true"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["vault.${var.domain}"]
      secret_name = "vault-tls"
    }

    rule {
      host = "vault.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "vault"
              port {
                number = 8200
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.vault]
}

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
