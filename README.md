# Proxmox Homelab

Infrastructure-as-Code repository for a production-grade homelab running on Proxmox VE with Kubernetes, HashiCorp Vault Enterprise, and integrated monitoring.

## Architecture

```text
+---------------------------------------------------------------------+
|                            Internet                                 |
|                               |                                     |
|                    Cloudflare DNS (*.proxcloud.io)                  |
|                               |                                     |
+-------------------------------+-------------------------------------+
|                         Home Network                                |
|  +----------------------------+----------------------------------+  |
|  |              Proxmox VE (pve01.proxcloud.io)                  |  |
|  |  +----------------------------------------------------------+ |  |
|  |  |            Kubernetes Cluster (k3s)                      | |  |
|  |  |  +----------+ +----------+ +----------+ +----------+     | |  |
|  |  |  |  Vault   | | Grafana  | |Prometheus| |   Flux   |     | |  |
|  |  |  |Enterprise| |  Stack   | |  + Loki  | |          |     | |  |
|  |  |  +----------+ +----------+ +----------+ +----------+     | |  |
|  |  |                    Traefik Ingress                       | |  |
|  |  +----------------------------------------------------------+ |  |
|  +---------------------------------------------------------------+  |
+---------------------------------------------------------------------+
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| Proxmox VE | https://pve01.proxcloud.io | Hypervisor management |
| Vault Enterprise | https://vault.proxcloud.io | Secrets management |
| Grafana | https://grafana.proxcloud.io | Monitoring dashboards |
| Prometheus | https://prometheus.proxcloud.io | Metrics |

## Repository Structure

```text
.
├── .github/workflows/    # GitHub Actions CI/CD
├── .pre-commit-config.yaml
├── packer/               # VM image templates
│   └── proxmox/
│       └── ubuntu-2404-server/
├── terraform/
│   ├── modules/          # Reusable Terraform modules
│   │   └── proxmox-vm/
│   └── stacks/           # Deployment stacks (ordered)
│       ├── 01-infrastructure/
│       ├── 02-kubernetes/
│       ├── 03-platform/
│       └── 04-applications/
├── kubernetes/
│   ├── clusters/
│   │   └── homelab/      # Flux cluster configuration
│   │       └── flux-system/
│   ├── infrastructure/   # Core K8s components (ingress, certs, metallb)
│   └── apps/             # Application deployments
└── docs/                 # Architecture docs and runbooks
```

## Getting Started

### Prerequisites

Before starting, ensure you have the following installed on your local machine:

**Required Tools:**

```bash
# macOS (using Homebrew)
brew install terraform packer kubectl flux

# Verify installations
terraform --version
packer --version
kubectl version --client
flux --version
```

**Required Accounts and Access:**

- Proxmox VE 8.x installed and accessible
- Cloudflare account with domain configured
- GitHub account with this repository cloned

### Step 1: Clone and Setup Local Environment

```bash
# Clone the repository (if not already done)
git clone https://github.com/timkrebs/proxmox-homelab.git
cd proxmox-homelab

# Install pre-commit hooks for code quality
pip install pre-commit
make pre-commit-install

# Check all dependencies are available
make pre-commit-check
```

Install any missing dependencies shown by `pre-commit-check`:

```bash
# macOS
brew install tflint trivy kubeconform shellcheck shfmt gitleaks
```

### Step 2: Configure GitHub Secrets

Add the following secrets to your GitHub repository at `Settings > Secrets and variables > Actions`:

| Secret Name | Description |
|-------------|-------------|
| `PROXMOX_API_URL` | Proxmox API URL (e.g., `https://pve01.proxcloud.io:8006/api2/json`) |
| `PROXMOX_API_TOKEN_ID` | API token ID (e.g., `terraform@pam!terraform`) |
| `PROXMOX_API_TOKEN_SECRET` | API token secret |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with DNS edit permissions |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID for your domain |
| `PACKER_SSH_PASSWORD` | Temporary password for Packer builds (default: `packer`) |

**Note:** The `PACKER_SSH_PASSWORD` must match the password hash in `packer/proxmox/ubuntu-2404-server/http/user-data`. The default is `packer`. To change it:

```bash
# Generate a new password hash
echo 'your-new-password' | mkpasswd -m sha-512 -s

# Update the hash in http/user-data and set PACKER_SSH_PASSWORD to 'your-new-password'
```

### Step 3: Create Proxmox API Token

On your Proxmox server:

```bash
# Create a user for Terraform
pveum user add terraform@pam

# Create an API token
pveum user token add terraform@pam terraform --privsep=0

# Grant necessary permissions
pveum aclmod / -user terraform@pam -role PVEAdmin
```

Save the token ID and secret for GitHub secrets.

### Step 4: Build VM Images with Packer

Build the base Ubuntu 24.04 template that will be used for Kubernetes nodes:

```bash
# Validate Packer template
make packer-validate

# Build the image (or trigger via GitHub Actions)
cd packer/proxmox/ubuntu-2404-server
packer init .
packer build \
  -var "proxmox_api_url=$PROXMOX_API_URL" \
  -var "proxmox_api_token_id=$PROXMOX_API_TOKEN_ID" \
  -var "proxmox_api_token_secret=$PROXMOX_API_TOKEN_SECRET" \
  .
```

### Step 5: Deploy Infrastructure with Terraform

Deploy infrastructure in order (each stack depends on the previous):

```bash
# Initialize all Terraform workspaces
make init

# Validate configuration
make validate

# Deploy infrastructure (VMs, networking)
cd terraform/stacks/01-infrastructure
terraform plan
terraform apply

# Deploy Kubernetes cluster
cd ../02-kubernetes
terraform plan
terraform apply
```

### Step 6: Configure kubectl Access

After the Kubernetes cluster is deployed:

```bash
# Copy kubeconfig from the control plane node
scp user@k8s-control-01.proxcloud.io:~/.kube/config ~/.kube/homelab-config

# Set the kubeconfig
export KUBECONFIG=~/.kube/homelab-config

# Verify cluster access
kubectl get nodes
kubectl cluster-info
```

### Step 7: Bootstrap Flux GitOps

Bootstrap Flux to enable GitOps deployments:

```bash
# Check prerequisites
flux check --pre

# Bootstrap Flux with your GitHub repository
flux bootstrap github \
  --owner=timkrebs \
  --repository=proxmox-homelab \
  --branch=main \
  --path=kubernetes/clusters/homelab \
  --personal

# Verify Flux is running
flux check
kubectl get pods -n flux-system
```

### Step 8: Verify Deployments

Once Flux is bootstrapped, it will automatically deploy:

1. **Infrastructure components** (cert-manager, metallb, traefik)
2. **Applications** (vault-enterprise, monitoring stack)

Monitor the deployment progress:

```bash
# Watch Flux reconciliation
flux get kustomizations --watch

# Check HelmReleases
flux get helmreleases -A

# View pod status
kubectl get pods -A
```

## Development Workflow

### Running Validations

```bash
# Run all pre-commit hooks
make pre-commit

# Validate Terraform
make validate

# Validate Kubernetes manifests
make k8s-validate

# Lint all files
make lint
```

### Making Changes

1. Create a feature branch
2. Make changes
3. Run `make pre-commit` to validate
4. Commit and push
5. Open a Pull Request
6. GitHub Actions will run validations
7. Merge to `main` triggers Flux deployment

### Useful Make Targets

```bash
make help              # Show all available targets
make init              # Initialize Terraform workspaces
make validate          # Validate Terraform configuration
make plan              # Plan all stacks
make apply             # Apply all stacks (with confirmation)
make packer-validate   # Validate Packer templates
make packer-build      # Build VM images
make pre-commit        # Run pre-commit hooks
make pre-commit-check  # Check dependencies
make flux-bootstrap    # Bootstrap Flux GitOps
make k8s-validate      # Validate Kubernetes manifests
make clean             # Clean temporary files
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Hypervisor | Proxmox VE 8.x |
| IaC | Terraform |
| Image Building | Packer |
| Container Orchestration | Kubernetes (k3s) |
| GitOps | Flux v2 |
| Secrets | HashiCorp Vault Enterprise |
| Monitoring | Grafana + Prometheus + Loki |
| DNS | Cloudflare |
| Certificates | cert-manager + Let's Encrypt |
| Ingress | Traefik |
| Load Balancer | MetalLB |

## Troubleshooting

### Flux Issues

```bash
# Check Flux logs
flux logs

# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# Check events
kubectl get events -n flux-system
```

### Terraform Issues

```bash
# Reinitialize with clean state
cd terraform/stacks/01-infrastructure
rm -rf .terraform
terraform init

# View state
terraform state list
```

### Kubernetes Issues

```bash
# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Describe resources
kubectl describe pod -n <namespace> <pod-name>

# Check resource status
kubectl get all -A
```

## Documentation

- [Architecture Decision Records](docs/adr/) - Key design decisions
- [Kubernetes Distribution Choice](docs/adr/001-kubernetes-distribution.md)

## License

MIT License - See [LICENSE](LICENSE) for details.
