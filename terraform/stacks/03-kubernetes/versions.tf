terraform {
  required_version = ">= 1.13.0"

  cloud {
    organization = "tim-krebs-org"

    workspaces {
      name = "infra-kubernetes"
    }
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
