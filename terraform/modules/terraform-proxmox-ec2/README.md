# terraform-proxmox-ec2

Terraform module that provisions a single VM on Proxmox Virtual Environment with an EC2-like interface.

## Usage

```hcl
module "ec2_instance" {
  source  = "app.terraform.io/YOUR_ORG/ec2/proxmox"
  version = "1.0.0"

  name          = "my-app-server"
  instance_type = "t3.medium"

  target_node = "pve"
  template_id = 9000

  ip_address = "192.168.1.50/24"
  gateway    = "192.168.1.1"

  ssh_public_keys = ["ssh-rsa AAAA..."]

  tags = {
    Environment = "dev"
    Project     = "my-project"
  }
}
```

## Instance Types

| Type | vCPUs | Memory | Packer Template ID |
|------|-------|--------|--------------------|
| `t3.small` | 2 | 2 GB | 9012 |
| `t3.medium` | 2 | 4 GB | 9013 |
| `t3.large` | 2 | 8 GB | 9014 |
| `t3.xlarge` | 4 | 16 GB | 9015 |
| `t3.2xlarge` | 8 | 32 GB | 9016 |
| `custom` | `custom_cores` | `custom_memory` | - |

### Custom sizing

```hcl
module "ec2_instance" {
  source = "app.terraform.io/YOUR_ORG/ec2/proxmox"

  name          = "beefy-server"
  instance_type = "custom"
  custom_cores  = 16
  custom_memory = 65536  # 64 GB

  # ... other variables
}
```

## Cloud-Init User Data

Pass custom cloud-init scripts via `user_data`:

```hcl
module "ec2_instance" {
  source = "app.terraform.io/YOUR_ORG/ec2/proxmox"

  name          = "web-server"
  instance_type = "t3.medium"

  user_data = <<-EOF
    #cloud-config
    packages:
      - nginx
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
  EOF

  # ... other variables
}
```

## Prerequisites

- Proxmox VE 7+ with API access
- A VM template with cloud-init and qemu-guest-agent (e.g., Ubuntu 24.04)
- Proxmox storage with `snippets` content type enabled (only if using `user_data`)
- SSH key-based access to the Proxmox host (required by the bpg/proxmox provider)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | Name of the virtual machine | `string` | - | yes |
| `vm_id` | Proxmox VM ID | `number` | `null` (auto) | no |
| `instance_type` | Instance type for sizing | `string` | `"t3.micro"` | no |
| `custom_cores` | CPU cores (when `instance_type = "custom"`) | `number` | `null` | no |
| `custom_memory` | Memory in MB (when `instance_type = "custom"`) | `number` | `null` | no |
| `target_node` | Proxmox node to deploy on | `string` | - | yes |
| `template_id` | VM template ID to clone from | `number` | - | yes |
| `disk_size` | Root disk size in GB | `number` | `20` | no |
| `storage_pool` | Proxmox storage pool | `string` | `"local-lvm"` | no |
| `snippets_storage` | Proxmox storage for cloud-init snippets | `string` | `"local"` | no |
| `ip_address` | Static IP in CIDR notation | `string` | - | yes |
| `gateway` | Network gateway IP | `string` | - | yes |
| `network_bridge` | Proxmox network bridge | `string` | `"vmbr0"` | no |
| `ssh_user` | Cloud-init user | `string` | `"ubuntu"` | no |
| `ssh_public_keys` | SSH public keys for VM access | `list(string)` | - | yes |
| `user_data` | Cloud-init user data (raw YAML) | `string` | `null` | no |
| `tags` | Tags for the VM | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | Proxmox VM ID |
| `instance_name` | VM name |
| `private_ip` | Private IP address |
| `mac_address` | MAC address |
| `ssh_connection` | SSH connection string |

## Building Packer Templates

Build instance type templates using the Packer config in `packer/proxmox/ubuntu-noble-instances/`:

```bash
cd packer/proxmox/ubuntu-noble-instances
packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.micro" .
packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.medium" .
```

## Publishing to HCP Terraform Private Registry

1. Move this module to its own Git repository named `terraform-proxmox-ec2`
2. Connect the repository to your HCP Terraform organization
3. Publish via the HCP Terraform registry UI
