# Proxmox Homelab

Infrastructure-as-Code repository for a production-grade homelab running on Proxmox VE with Kubernetes, HashiCorp Vault Enterprise, and integrated monitoring.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                            Internet                                 │
│                               │                                     │
│                    Cloudflare DNS (*.proxcloud.io)                  │
│                               │                                     │
├───────────────────────────────┼─────────────────────────────────────┤
│                         Home Network                                │
│  ┌────────────────────────────┼──────────────────────────────────┐  │
│  │              Proxmox VE (pve01.proxcloud.io)                  │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │            Kubernetes Cluster (k3s)                      │ │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │ │  │
│  │  │  │  Vault   │ │ Grafana  │ │Prometheus│ │  ArgoCD  │     │ │  │
│  │  │  │Enterprise│ │  Stack   │ │  + Loki  │ │          │     │ │  │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘     │ │  │
│  │  │                    Traefik Ingress                       │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔗 Services

| Service | URL | Description |
|---------|-----|-------------|
| Proxmox VE | https://pve01.proxcloud.io | Hypervisor management |
| Vault Enterprise | https://vault.proxcloud.io | Secrets management |
| Grafana | https://grafana.proxcloud.io | Monitoring dashboards |
| Prometheus | https://prometheus.proxcloud.io | Metrics |
| ArgoCD | https://argocd.proxcloud.io | GitOps |

## 📁 Repository Structure

```
├── .github/workflows/    # GitHub Actions CI/CD
├── packer/              # VM image templates
├── terraform/
│   ├── modules/         # Reusable Terraform modules
│   └── stacks/          # Deployment stacks (infrastructure → apps)
├── kubernetes/
│   ├── infrastructure/  # Core K8s components (ingress, certs)
│   └── apps/           # Application deployments
├── ansible/            # Configuration management
├── scripts/            # Utility scripts
└── docs/               # Architecture docs & runbooks
```

## 🚀 Getting Started

### Prerequisites

- Proxmox VE 8.x installed and accessible
- Cloudflare account with domain configured
- HCP account (Terraform Cloud + Packer)
- GitHub repository with Actions enabled

### 1. Configure Secrets

Add these secrets to your GitHub repository:

```bash
# HCP Credentials
HCP_CLIENT_ID
HCP_CLIENT_SECRET
HCP_PROJECT_ID

# Terraform Cloud
TF_API_TOKEN

# Proxmox
PROXMOX_API_URL
PROXMOX_API_TOKEN_ID
PROXMOX_API_TOKEN_SECRET

# Cloudflare
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ZONE_ID

# Packer
PACKER_SSH_PASSWORD
```

### 2. Build VM Images

```bash
# Manually trigger Packer build
gh workflow run packer-build.yml -f template=ubuntu-2404-server
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform workspaces
cd terraform/stacks/01-infrastructure
terraform init
terraform plan
terraform apply
```

### 4. Bootstrap Kubernetes

```bash
# After VMs are created
cd terraform/stacks/02-kubernetes
terraform apply

# Export kubeconfig
export KUBECONFIG=~/.kube/homelab-config
```

### 5. Deploy Applications

GitOps will automatically deploy applications when changes are pushed to `main`.

## 🔧 Tech Stack

| Layer | Technology |
|-------|------------|
| Hypervisor | Proxmox VE 8.x |
| IaC | Terraform (HCP Terraform Enterprise) |
| Image Building | Packer (HCP Packer) |
| Container Orchestration | Kubernetes (k3s) |
| GitOps | Flux / ArgoCD |
| Secrets | HashiCorp Vault Enterprise |
| Monitoring | Grafana + Prometheus + Loki |
| DNS | Cloudflare |
| Certificates | cert-manager + Let's Encrypt |
| Ingress | Traefik |

## 📚 Documentation

Detailed documentation is maintained in Obsidian:
- Architecture decisions
- Runbooks
- Troubleshooting guides

## 🤝 Contributing

1. Create a feature branch
2. Make changes
3. Open a Pull Request
4. GitHub Actions will run validation
5. Merge to `main` triggers deployment

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.
