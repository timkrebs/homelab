# terraform-proxmox-kubernetes

Terraform module that deploys a K3s Kubernetes cluster on Proxmox Virtual Environment.

## Architecture

```
    ┌──────────────────────────┐
    │   Proxmox VE Node        │
    │                          │
    │  ┌────────────────────┐  │
    │  │ Control Plane VM   │  │
    │  │ - K3s Server       │  │
    │  │ - API Server :6443 │  │
    │  └────────────────────┘  │
    │                          │
    │  ┌────────────────────┐  │
    │  │ Worker VM 01       │  │
    │  │ - K3s Agent        │  │
    │  └────────────────────┘  │
    │                          │
    │  ┌────────────────────┐  │
    │  │ Worker VM N        │  │
    │  │ - K3s Agent        │  │
    │  └────────────────────┘  │
    └──────────────────────────┘
```

## Prerequisites

- Proxmox VE 7+ with API access
- A VM template with cloud-init and qemu-guest-agent (e.g., Ubuntu 24.04)
- Proxmox storage with `snippets` content type enabled (for cloud-init scripts)
- SSH key-based access to the Proxmox host (required by the bpg/proxmox provider)

## Usage

```hcl
module "kubernetes" {
  source = "app.terraform.io/YOUR_ORG/kubernetes/proxmox"

  cluster_name = "my-k3s-cluster"
  environment  = "dev"

  # Proxmox target
  proxmox_node = "pve"
  template_id  = 9000

  # Control plane sizing
  control_plane_instance_type = "t3.large"

  # Worker sizing
  worker_count         = 2
  worker_instance_type = "t3.xlarge"

  # Network
  network_bridge  = "vmbr0"
  network_gateway = "192.168.1.1"
  control_plane_ips = ["192.168.1.100/24"]
  worker_ips        = ["192.168.1.101/24", "192.168.1.102/24"]

  # SSH
  ssh_user        = "ubuntu"
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
| `t3.nano` | 2 | 0.5 GB | 9010 |
| `t3.micro` | 2 | 1 GB | 9011 |
| `t3.small` | 2 | 2 GB | 9012 |
| `t3.medium` | 2 | 4 GB | 9013 |
| `t3.large` | 2 | 8 GB | 9014 |
| `t3.xlarge` | 4 | 16 GB | 9015 |
| `t3.2xlarge` | 8 | 32 GB | 9016 |

## Retrieving kubeconfig

After the cluster is deployed, retrieve the kubeconfig:

```bash
scp ubuntu@<CONTROL_PLANE_IP>:/etc/rancher/k3s/k3s.yaml ./kubeconfig
sed -i '' 's|127.0.0.1|<CONTROL_PLANE_IP>|g' ./kubeconfig
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

Or use the `kubeconfig_command` output directly.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | Name prefix for all cluster resources | `string` | - | yes |
| `environment` | Environment tag | `string` | `"dev"` | no |
| `proxmox_node` | Proxmox node name to deploy on | `string` | - | yes |
| `template_id` | VM template ID to clone from | `number` | - | yes |
| `storage_pool` | Proxmox storage pool for VM disks | `string` | `"local-lvm"` | no |
| `snippets_storage` | Proxmox storage for cloud-init snippets | `string` | `"local"` | no |
| `control_plane_count` | Number of control plane nodes (only 1 supported) | `number` | `1` | no |
| `control_plane_instance_type` | Instance type for control plane | `string` | `"t3.large"` | no |
| `control_plane_disk_size` | Disk size in GB for control plane | `number` | `50` | no |
| `control_plane_ips` | Static IPs in CIDR for control plane | `list(string)` | - | yes |
| `worker_count` | Number of worker nodes | `number` | `2` | no |
| `worker_instance_type` | Instance type for workers | `string` | `"t3.xlarge"` | no |
| `worker_disk_size` | Disk size in GB for each worker | `number` | `100` | no |
| `worker_ips` | Static IPs in CIDR for workers | `list(string)` | - | yes |
| `network_bridge` | Proxmox network bridge | `string` | `"vmbr0"` | no |
| `network_gateway` | Network gateway IP | `string` | - | yes |
| `ssh_user` | Cloud-init user | `string` | `"ubuntu"` | no |
| `ssh_public_keys` | SSH public keys for VM access | `list(string)` | - | yes |
| `k3s_version` | K3s version to install | `string` | `"v1.31.4+k3s1"` | no |
| `cluster_cidr` | Pod network CIDR | `string` | `"10.42.0.0/16"` | no |
| `service_cidr` | Service network CIDR | `string` | `"10.43.0.0/16"` | no |
| `cluster_dns` | Cluster DNS IP | `string` | `"10.43.0.10"` | no |
| `disable_components` | K3s components to disable | `list(string)` | `["traefik", "servicelb"]` | no |
| `flannel_backend` | Flannel CNI backend type | `string` | `"vxlan"` | no |
| `tags` | Tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_name` | The K3s cluster name |
| `control_plane_ips` | Control plane node IPs |
| `worker_ips` | Worker node IPs |
| `control_plane_vm_ids` | Proxmox VM IDs for control plane |
| `worker_vm_ids` | Proxmox VM IDs for workers |
| `kubernetes_api_url` | Kubernetes API server URL |
| `k3s_token` | K3s cluster join token (sensitive) |
| `ssh_user` | SSH user for node access |
| `kubeconfig_command` | Command to retrieve kubeconfig |

## Building Packer Templates

Build instance type templates using the Packer config in `packer/proxmox/ubuntu-noble-instances/`:

```bash
cd packer/proxmox/ubuntu-noble-instances
packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.large" .
packer build -var-file="../credentials.pkr.hcl" -var "instance_type=t3.xlarge" .
```

## Publishing to HCP Terraform Private Registry

1. Move this module to its own Git repository named `terraform-proxmox-kubernetes`
2. Connect the repository to your HCP Terraform organization
3. Publish via the HCP Terraform registry UI
