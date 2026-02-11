# terraform-proxmox-rds

Terraform module that provisions a managed PostgreSQL database on Proxmox Virtual Environment with an AWS RDS-like interface.

## Usage

```hcl
module "db" {
  source  = "app.terraform.io/YOUR_ORG/rds/proxmox"
  version = "1.0.0"

  identifier     = "my-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.medium"

  allocated_storage = 50
  db_name           = "myapp"
  db_username       = "admin"
  db_password       = var.db_password

  target_node = "pve"
  template_id = 9000

  ip_address = "192.168.1.60/24"
  gateway    = "192.168.1.1"

  ssh_public_keys = ["ssh-rsa AAAA..."]

  allowed_cidrs = ["192.168.1.0/24"]

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}
```

## Instance Classes

| Class | vCPUs | Memory | Recommended Use |
|-------|-------|--------|-----------------|
| `db.t3.small` | 2 | 2 GB | Small applications |
| `db.t3.medium` | 2 | 4 GB | Medium workloads |
| `db.t3.large` | 2 | 8 GB | Production |
| `db.t3.xlarge` | 4 | 16 GB | High-performance |
| `db.t3.2xlarge` | 8 | 32 GB | Large-scale production |
| `custom` | `custom_cores` | `custom_memory` | Custom sizing |

### Custom sizing

```hcl
module "db" {
  source = "app.terraform.io/YOUR_ORG/rds/proxmox"

  identifier     = "big-postgres"
  instance_class = "custom"
  custom_cores   = 16
  custom_memory  = 65536  # 64 GB

  # ... other variables
}
```

## Supported Engines

| Engine | Versions |
|--------|----------|
| `postgres` | 14, 15, 16, 17 |

More engines (MySQL, MariaDB, MongoDB) will be added in future releases.

## PostgreSQL Tuning

The module automatically tunes PostgreSQL based on the instance class memory:

| Parameter | Formula |
|-----------|---------|
| `shared_buffers` | 25% of total memory |
| `effective_cache_size` | 75% of total memory |
| `work_mem` | total memory / 64 (min 4 MB) |
| `maintenance_work_mem` | total memory / 16 (min 64 MB) |

## Prerequisites

- Proxmox VE 7+ with API access
- A VM template with cloud-init and qemu-guest-agent (e.g., Ubuntu 24.04)
- Proxmox storage with `snippets` content type enabled
- SSH key-based access to the Proxmox host (required by the bpg/proxmox provider)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `identifier` | Database instance name | `string` | - | yes |
| `vm_id` | Proxmox VM ID | `number` | `null` (auto) | no |
| `engine` | Database engine | `string` | `"postgres"` | no |
| `engine_version` | Engine major version | `string` | `"16"` | no |
| `instance_class` | Instance class for sizing | `string` | `"db.t3.micro"` | no |
| `custom_cores` | CPU cores (when `instance_class = "custom"`) | `number` | `null` | no |
| `custom_memory` | Memory in MB (when `instance_class = "custom"`) | `number` | `null` | no |
| `allocated_storage` | Disk size in GB | `number` | `20` | no |
| `storage_pool` | Proxmox storage pool | `string` | `"local-lvm"` | no |
| `snippets_storage` | Proxmox storage for cloud-init snippets | `string` | `"local"` | no |
| `db_name` | Initial database name | `string` | - | yes |
| `db_username` | Master username | `string` | - | yes |
| `db_password` | Master password | `string` | - | yes |
| `port` | Database port | `number` | `5432` | no |
| `listen_addresses` | PostgreSQL listen_addresses | `string` | `"*"` | no |
| `allowed_cidrs` | CIDRs allowed to connect | `list(string)` | `["0.0.0.0/0"]` | no |
| `target_node` | Proxmox node to deploy on | `string` | - | yes |
| `template_id` | VM template ID to clone from | `number` | - | yes |
| `ip_address` | Static IP in CIDR notation | `string` | - | yes |
| `gateway` | Network gateway IP | `string` | - | yes |
| `network_bridge` | Proxmox network bridge | `string` | `"vmbr0"` | no |
| `ssh_user` | Cloud-init user | `string` | `"ubuntu"` | no |
| `ssh_public_keys` | SSH public keys for VM access | `list(string)` | - | yes |
| `tags` | Tags for the VM | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `db_instance_id` | Proxmox VM ID |
| `db_instance_name` | VM name |
| `endpoint` | Connection endpoint (address:port) |
| `address` | IP address |
| `port` | Database port |
| `db_name` | Database name |
| `db_username` | Master username |
| `connection_string` | Full PostgreSQL connection string (sensitive) |
| `ssh_connection` | SSH connection string for management |

## Building Packer Templates

Use the Packer config in `packer/proxmox/ubuntu-noble-instances/` or `packer/proxmox/ubuntu-server-noble/`:

```bash
cd packer/proxmox/ubuntu-server-noble
packer build -var-file="../credentials.pkr.hcl" .
```

## Publishing to HCP Terraform Private Registry

1. Move this module to its own Git repository named `terraform-proxmox-rds`
2. Connect the repository to your HCP Terraform organization
3. Publish via the HCP Terraform registry UI
