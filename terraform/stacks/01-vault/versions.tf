terraform {
  required_version = ">= 1.13.0"

  cloud {
    organization = "tim-krebs-org"

    workspaces {
      name = "infra-vault"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2"
    }
  }
}
