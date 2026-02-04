# ADR 001: Kubernetes Distribution Selection

## Status

Accepted

## Context

We need to select a Kubernetes distribution for our Proxmox homelab that balances ease of deployment, resource efficiency, and feature completeness.

### Options Considered

1. **k3s** - Lightweight Kubernetes by Rancher
2. **RKE2** - Enterprise-grade Kubernetes by Rancher
3. **kubeadm** - Official Kubernetes installation tool
4. **k0s** - Zero-friction Kubernetes by Mirantis

## Decision

We will use **k3s** for the homelab Kubernetes cluster.

## Rationale

- **Resource Efficiency**: k3s runs with ~512MB RAM vs 1GB+ for others
- **Simplified Installation**: Single binary, easy to deploy via Terraform
- **CNCF Conformant**: Fully conformant Kubernetes distribution
- **Built-in Components**: Includes containerd, CoreDNS, and can include Traefik
- **HA Support**: Native HA with embedded etcd (from k3s 1.19+)
- **Community**: Large community, well-documented

### Trade-offs

- Less "enterprise" than RKE2 (no default CIS hardening)
- Some components differ from upstream (SQLite default vs etcd)

## Consequences

- We disable k3s built-in Traefik to install our own version
- We disable k3s built-in ServiceLB to use MetalLB
- VM templates must include k3s prerequisites (containerd)
- HA requires minimum 3 server nodes for embedded etcd

## References

- [k3s Documentation](https://docs.k3s.io/)
- [k3s vs RKE2](https://docs.ranchermanager.rancher.io/v2.6/pages-for-subheaders/rancher-managed-clusters)
