# Proxmox Kubernetes Engine (PKE) Cluster

This directory contains Terraform code to create a Proxmox Kubernetes Engine (PKE) cluster using the `terraform-proxmox-pke` module. The cluster consists of 1 control plane node and 3 worker nodes running K3s.

## Prerequisites

- Proxmox VE 7+ with API access
- A VM template with cloud-init and qemu-guest-agent (e.g., Ubuntu 24.04, template ID 9000)
- `kubectl` installed locally

## Deploy the cluster

```bash
terraform init
terraform apply
```

## Connect to the cluster

Retrieve the kubeconfig from the control plane node:

```bash
# Copy kubeconfig from control plane
scp timkrebs@192.168.1.160:/etc/rancher/k3s/k3s.yaml ./kubeconfig

# Replace localhost with the control plane IP
sed -i '' 's|127.0.0.1|192.168.1.160|g' ./kubeconfig

# Or use the generated command directly
$(terraform output -raw kubeconfig_command)
```

Set the `KUBECONFIG` environment variable:

```bash
export KUBECONFIG=./kubeconfig
```

Verify the cluster is running:

```bash
kubectl get nodes
kubectl get pods -A
```

## Setup Vault with Kubernetes HA and TLS
https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls#prerequisites