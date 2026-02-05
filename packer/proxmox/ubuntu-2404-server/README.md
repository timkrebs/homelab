# Ubuntu 24.04 Server Packer Template for Proxmox

This directory contains Packer configuration to build an Ubuntu 24.04 Server template for Proxmox VE.

## Prerequisites

1. **Packer** installed (v1.10+): https://developer.hashicorp.com/packer/downloads
2. **Proxmox VE** with API access configured
3. **Ubuntu 24.04 ISO** uploaded to Proxmox (e.g., `local:iso/ubuntu-24.04.2-live-server-amd64.iso`)

## Quick Start

### Option 1: Local Build (Recommended)

Run the build script from a machine with network access to your Proxmox server:

```bash
# 1. Copy the secrets template and fill in your values
cp secrets.pkrvars.hcl.example secrets.pkrvars.hcl
# Edit secrets.pkrvars.hcl with your Proxmox credentials

# 2. Run the build
./build.sh

# Or with environment variables
export PROXMOX_API_URL="https://pve01.example.com:8006/api2/json"
export PROXMOX_API_TOKEN_ID="packer@pam!packer-token"
export PROXMOX_API_TOKEN_SECRET="your-secret-here"
./build.sh
```

### Option 2: Manual Packer Commands

```bash
# Initialize plugins
packer init .

# Validate template
packer validate -var-file=secrets.pkrvars.hcl .

# Build
packer build -var-file=secrets.pkrvars.hcl .

# Build with debug logging
PACKER_LOG=1 packer build -var-file=secrets.pkrvars.hcl .
```

### Option 3: GitHub Actions (Requires Self-Hosted Runner)

The workflow at `.github/workflows/packer-build.yml` can automate builds, but requires a self-hosted runner in your homelab with network access to Proxmox.

**Why?** GitHub-hosted runners cannot reach private homelab networks. The Packer build needs to:

1. Connect to Proxmox API (typically on a private IP)
2. SSH into the VM being built (private IP assigned by DHCP)

## Configuration

### Required Secrets (for GitHub Actions)

| Secret | Description |
|--------|-------------|
| `PROXMOX_API_URL` | Proxmox API endpoint (e.g., `https://pve01:8006/api2/json`) |
| `PROXMOX_API_TOKEN_ID` | API token ID (e.g., `packer@pam!packer-token`) |
| `PROXMOX_API_TOKEN_SECRET` | API token secret |
| `PACKER_SSH_PASSWORD` | SSH password for build user (default: `packer`) |

### Variables

See [variables.pkr.hcl](variables.pkr.hcl) for all available variables.

| Variable | Default | Description |
|----------|---------|-------------|
| `proxmox_node` | `pve01` | Proxmox node name |
| `vm_id` | `9000` | Template VM ID |
| `storage_pool` | `local-lvm` | Storage pool for VM disk |
| `ssh_username` | `packer` | Build-time SSH user |
| `ssh_password` | `packer` | Build-time SSH password |

## Troubleshooting

### SSH Connection Timeout

The most common issue. Check:

1. **Network connectivity**: Can you ping the VM's IP from your build machine?
2. **Autoinstall completion**: The VM may still be installing. Increase `ssh_timeout` in the template.
3. **DHCP**: Ensure the VM gets an IP address. Check Proxmox console.
4. **Firewall**: Ensure port 22 is open on the VM.

### Build hangs at "Waiting for SSH"

```bash
# Enable debug logging
PACKER_LOG=1 packer build -var-file=secrets.pkrvars.hcl .
```

Check the Proxmox web UI to see the VM console - the autoinstall might have failed or be waiting for input.

### cloud-init Issues

The template removes old cloud-init configs and sets up Proxmox-compatible cloud-init. If you have networking issues on cloned VMs:

1. Ensure `files/99-pve.cfg` is properly copied
2. Check that netplan configs are removed during build

## File Structure

```text
ubuntu-2404-server/
├── ubuntu-2404.pkr.hcl      # Main Packer template
├── variables.pkr.hcl         # Variable definitions
├── build.sh                  # Local build script
├── secrets.pkrvars.hcl.example # Secrets template
├── files/
│   └── 99-pve.cfg           # Cloud-init config for Proxmox
├── http/
│   ├── meta-data            # Cloud-init meta-data (empty)
│   └── user-data            # Ubuntu autoinstall config
└── scripts/
    ├── setup.sh             # Base system setup
    ├── cleanup.sh           # Pre-template cleanup
    └── k8s-prereqs.sh       # Kubernetes prerequisites (optional)
```

## Setting Up a Self-Hosted Runner

To run builds via GitHub Actions:

1. On a machine in your homelab (e.g., the Proxmox host itself or a dedicated VM):

   ```bash
   # Download runner
   mkdir actions-runner && cd actions-runner
   curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
   tar xzf ./actions-runner-linux-x64.tar.gz

   # Configure (get token from GitHub repo Settings > Actions > Runners)
   ./config.sh --url https://github.com/YOUR_USERNAME/YOUR_REPO --token YOUR_TOKEN --labels proxmox

   # Install as service
   sudo ./svc.sh install
   sudo ./svc.sh start
   ```

2. Add repository secrets in GitHub (Settings > Secrets and variables > Actions)

3. Trigger a build via workflow dispatch or push to main/development branches
