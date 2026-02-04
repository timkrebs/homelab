terraform {
  required_version = ">= 1.5.0"

  # Terraform Cloud backend - organization set via TF_CLOUD_ORGANIZATION env var
  cloud {
    workspaces {
      name = "homelab-platform"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Reference outputs from 02-kubernetes via Terraform Cloud
data "terraform_remote_state" "kubernetes" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = "homelab-kubernetes"
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

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# MetalLB for LoadBalancer services
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "metallb-system"
  create_namespace = true
  version          = var.metallb_version

  wait = true
}

# MetalLB IP Address Pool
resource "kubernetes_manifest" "metallb_ip_pool" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "default-pool"
      namespace = "metallb-system"
    }
    spec = {
      addresses = var.metallb_ip_range
    }
  }

  depends_on = [helm_release.metallb]
}

# MetalLB L2 Advertisement
resource "kubernetes_manifest" "metallb_l2_advertisement" {
  manifest = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "default"
      namespace = "metallb-system"
    }
    spec = {
      ipAddressPools = ["default-pool"]
    }
  }

  depends_on = [kubernetes_manifest.metallb_ip_pool]
}

# cert-manager for TLS certificates
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = var.cert_manager_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  wait = true
}

# ClusterIssuer for Let's Encrypt (DNS-01 with Cloudflare)
resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = "cloudflare-api-token"
                key  = "api-token"
              }
            }
          }
          selector = {
            dnsZones = [var.cloudflare_zone]
          }
        }]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# Cloudflare API token secret for cert-manager
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    "api-token" = var.cloudflare_api_token
  }

  depends_on = [helm_release.cert_manager]
}

# Traefik Ingress Controller
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik-system"
  create_namespace = true
  version          = var.traefik_version

  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
        annotations = {
          "metallb.universe.tf/loadBalancerIPs" = var.traefik_ip
        }
      }
      ports = {
        web = {
          redirectTo = {
            port = "websecure"
          }
        }
        websecure = {
          tls = {
            enabled = true
          }
        }
      }
      ingressRoute = {
        dashboard = {
          enabled = false
        }
      }
      providers = {
        kubernetesIngress = {
          publishedService = {
            enabled = true
          }
        }
      }
    })
  ]

  depends_on = [helm_release.metallb, kubernetes_manifest.metallb_ip_pool]
}

# Wildcard certificate for *.proxcloud.io
resource "kubernetes_manifest" "wildcard_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-proxcloud-io"
      namespace = "traefik-system"
    }
    spec = {
      secretName = "wildcard-proxcloud-io-tls"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      commonName = "*.${var.cloudflare_zone}"
      dnsNames = [
        var.cloudflare_zone,
        "*.${var.cloudflare_zone}"
      ]
    }
  }

  depends_on = [kubernetes_manifest.letsencrypt_issuer, helm_release.traefik]
}
