terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
  # Self-hosted Vault: no root namespace needed
  # For HCP Vault, set root_namespace = "admin"
}
