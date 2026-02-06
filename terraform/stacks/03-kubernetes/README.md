# 03 — K3s Kubernetes Cluster

Deploys a 3-node K3s Kubernetes cluster on Proxmox with TLS certificates issued by HashiCorp Vault's PKI secrets engine.

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                      Proxmox VE (pve01)                         │
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │  k8s-control-01      │  │  k8s-worker-01       │            │
│  │  192.168.1.140       │  │  192.168.1.141        │            │
│  │  2 vCPU / 8 GB RAM   │  │  4 vCPU / 16 GB RAM  │            │
│  │  50 GB disk          │  │  100 GB disk          │            │
│  │  K3s server          │  │  K3s agent            │            │
│  │  Vault TLS cert      │  │                       │            │
│  └──────────────────────┘  └──────────────────────┘            │
│                                                                 │
│                            ┌──────────────────────┐            │
│                            │  k8s-worker-02       │            │
│                            │  192.168.1.142        │            │
│                            │  4 vCPU / 16 GB RAM  │            │
│                            │  100 GB disk          │            │
│                            │  K3s agent            │            │
│                            └──────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴──────────┐
                    │  Vault PKI (pki_int)│
                    │  kubernetes-server  │
                    │  role issues TLS    │
                    └────────────────────┘
```

## Prerequisites

1. **01-vault** stack deployed and Vault unsealed
2. **02-vault-infra** stack applied with `enable_pki = true`
3. Vault PKI intermediate CA configured with `kubernetes-server` role
4. Ubuntu VM template available in Proxmox (ID 900 = Noble 24.04)

## Components

| Component | Purpose |
|-----------|---------|
| **Vault PKI Cert** | TLS certificate for K3s API server, issued via `pki_int/kubernetes-server` role |
| **K3s Server** | Control plane with embedded etcd, API server, scheduler, controller-manager |
| **K3s Agents** | Worker nodes joining via pre-shared token |
| **Cloudflare DNS** | A records for all nodes + `k8s.proxcloud.io` API + `*.k8s.proxcloud.io` ingress wildcard |
| **Vault KV** | K3s cluster token stored at `k3s/cluster-token` |

## What Gets Disabled

Per [ADR-001](../../docs/adr/001-kubernetes-distribution.md):

- **Traefik** — replaced by separately managed ingress controller
- **ServiceLB (Klipper)** — replaced by MetalLB

## Usage

```bash
# Initialize
cd terraform/stacks/03-kubernetes
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

## Post-Deployment

### 1. Wait for cloud-init

```bash
ssh ubuntu@192.168.1.140
sudo cloud-init status --wait
```

### 2. Verify cluster

```bash
ssh ubuntu@192.168.1.140
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
```

### 3. Retrieve kubeconfig

```bash
scp ubuntu@192.168.1.140:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update server address to use DNS
sed -i '' 's|127.0.0.1|k8s.proxcloud.io|g' ~/.kube/config
```

### 4. Enable Vault Kubernetes Auth

After the cluster is running, update `02-vault-infra/terraform.tfvars`:

```hcl
enable_kubernetes_auth = true
kubernetes_host        = "https://192.168.1.140:6443"
kubernetes_ca_cert     = "..."  # from: ssh ubuntu@192.168.1.140 sudo cat /var/lib/rancher/k3s/server/tls/server-ca.crt
```

Then re-apply `02-vault-infra`:

```bash
cd ../02-vault-infra
terraform apply
```

This enables cert-manager (once installed) to authenticate with Vault and issue TLS certificates from the PKI intermediate CA.

### 5. Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set crds.enabled=true
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `control_plane_ip` | `192.168.1.140` | Control plane static IP |
| `control_plane_cores` | `2` | CPU cores |
| `control_plane_memory` | `8192` | Memory (MB) |
| `worker_ips` | `{k8s-worker-01: .141, k8s-worker-02: .142}` | Worker node IPs |
| `worker_cores` | `4` | CPU cores per worker |
| `worker_memory` | `16384` | Memory (MB) per worker |
| `k3s_version` | `v1.31.4+k3s1` | K3s release version |
| `template_vm_id` | `900` | Ubuntu Noble 24.04 template |
| `vault_pki_mount` | `pki_int` | Vault PKI intermediate path |
| `vault_pki_role` | `kubernetes-server` | Vault PKI role for cert issuance |

## IP Address Allocation

| Range | Purpose |
|-------|---------|
| `192.168.1.130-133` | Vault cluster (01-vault) |
| `192.168.1.140` | K3s control plane |
| `192.168.1.141-142` | K3s worker nodes |
| `10.42.0.0/16` | Pod CIDR (K3s default) |
| `10.43.0.0/16` | Service CIDR (K3s default) |
