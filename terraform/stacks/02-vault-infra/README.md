# Vault Infrastructure (Terraform)

Terraform configuration for provisioning Vault resources including namespaces, secrets engines, PKI certificate authority, ACME, policies, and authentication methods.

## Overview

This module configures Vault with:

- Engineering namespace with KV-V2 secrets engines
- **PKI Root & Intermediate CA** for internal certificate management
- **ACME protocol** on intermediate CA (Vault 1.14+) for Let's Encrypt-style cert issuance
- **PKI roles** for Kubernetes TLS (server, client, wildcard)
- ACL policies for role-based access and certificate issuance
- Identity entities and aliases
- Userpass authentication for demo users
- **Kubernetes auth method** for K8s workloads and cert-manager
- **AppRole auth** for CI/CD certificate automation
- Optional database secrets engine

## Prerequisites

| Requirement | Description |
|-------------|-------------|
| Terraform | >= 1.5.0 |
| Vault | Running and accessible |
| Vault Token | Admin-level access token |

**Dependencies**: Requires [vault-ent](../vault-ent/) to be running and initialized.

## Quick Start

```bash
# 1. Ensure Vault is running
curl http://127.0.0.1:8200/v1/sys/health

# 2. Get the root token
export VAULT_TOKEN=$(cat ../vault-ent/vault-creds.txt | grep -A2 "ROOT TOKEN" | tail -1 | tr -d ' ')

# 3. Create terraform.tfvars
cat > terraform.tfvars << EOF
vault_address = "http://127.0.0.1:8200"
vault_token   = "$VAULT_TOKEN"
EOF

# 4. Initialize and apply
terraform init
terraform plan
terraform apply
```

## Project Structure

```text
vault-infra/
├── provider.tf        # Vault provider configuration
├── variables.tf       # Input variable definitions
├── main.tf            # Resource definitions
├── outputs.tf         # Output values
├── terraform.tf       # Terraform version constraints
└── terraform.tfvars   # Variable values (create this)
```

## Configuration

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `vault_address` | string | Vault cluster URL |
| `vault_token` | string | Admin token (sensitive) |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `engineering_namespace` | `engineering` | Team namespace name |
| `enable_database_secrets` | `false` | Enable PostgreSQL integration |
| `enable_pki` | `true` | Enable PKI CA and certificate management |
| `pki_domain` | `proxcloud.io` | Base domain for PKI certificates |
| `pki_organization` | `Homelab` | Organization name in certs |
| `pki_root_ttl` | `87600h` | Root CA lifetime (10 years) |
| `pki_int_ttl` | `43800h` | Intermediate CA lifetime (5 years) |
| `pki_cert_ttl` | `720h` | Default cert lifetime (30 days) |
| `pki_cert_max_ttl` | `2160h` | Max cert lifetime (90 days) |
| `enable_acme` | `false` | Enable ACME protocol on intermediate CA |
| `enable_kubernetes_auth` | `false` | Enable K8s auth method |
| `kubernetes_host` | `https://kubernetes.default.svc` | K8s API server |
| `kubernetes_allowed_namespaces` | `["default", "kube-system"]` | K8s namespaces for auth |

### Example terraform.tfvars

```hcl
vault_address = "http://127.0.0.1:8200"
vault_token   = "hvs.xxxxx"

# PKI / Certificate Management
enable_pki   = true
pki_domain   = "proxcloud.io"
enable_acme  = true
```

## Resources Created

### Namespace

```text
admin/
└── engineering/    <- Created namespace
```

### Secrets Engines

| Mount Path | Type | Purpose |
|------------|------|---------|
| `engineering/frontend-secrets` | kv-v2 | Frontend team secrets |
| `engineering/backend-secrets` | kv-v2 | Backend team secrets |
| `engineering/database` | database | Dynamic DB credentials (optional) |

### Secrets

**Frontend Secrets** (`frontend-secrets/`):

| Path | Keys |
|------|------|
| `app-config` | `api_endpoint`, `cdn_url`, `analytics_key` |
| `auth` | `oauth_client_id`, `oauth_redirect_uri` |

**Backend Secrets** (`backend-secrets/`):

| Path | Keys |
|------|------|
| `app-config` | `jwt_secret`, `encryption_key`, `api_rate_limit` |
| `external-services` | `payment_gateway_key`, `email_service_api_key` |

### Policies

**frontend-engineer**:

```hcl
# Read frontend secrets
path "engineering/frontend-secrets/data/*" {
  capabilities = ["read"]
}

# List frontend secrets
path "engineering/frontend-secrets/metadata/*" {
  capabilities = ["read", "list"]
}

# Token self-lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

**backend-engineer**:

```hcl
# Read backend secrets
path "engineering/backend-secrets/data/*" {
  capabilities = ["read"]
}

# Read database credentials
path "engineering/database/creds/backend-readonly" {
  capabilities = ["read"]
}

path "engineering/database/creds/backend-readwrite" {
  capabilities = ["read"]
}
```

### Auth Methods

**Userpass** (for demo):

| Username | Password | Policies |
|----------|----------|----------|
| `frontend-dev` | `<set via var>` | `frontend-engineer` |
| `backend-dev` | `<set via var>` | `backend-engineer` |

### Identity

| Entity | Policies | Alias |
|--------|----------|-------|
| `frontend-engineer` | `frontend-engineer` | `frontend-dev` (userpass) |
| `backend-engineer` | `backend-engineer` | `backend-dev` (userpass) |

## Outputs

| Output | Description |
|--------|-------------|
| `namespace_path` | Full path to engineering namespace |
| `frontend_entity_id` | Frontend engineer entity ID |
| `backend_entity_id` | Backend engineer entity ID |
| `secrets_engines` | Map of secrets engine paths |
| `database_roles` | Available database roles (if enabled) |
| `demo_users` | Demo user credentials |

## Usage Examples

### Login as Frontend Developer

```bash
export VAULT_ADDR=http://127.0.0.1:8200

# Login
vault login -method=userpass \
  username=frontend-dev \
  password=$FRONTEND_PASSWORD

# Read secrets
vault kv get -namespace=admin/engineering \
  frontend-secrets/app-config
```

### Login as Backend Developer

```bash
# Login
vault login -method=userpass \
  username=backend-dev \
  password=$BACKEND_PASSWORD

# Read secrets
vault kv get -namespace=admin/engineering \
  backend-secrets/app-config

# Get database credentials (if enabled)
vault read -namespace=admin/engineering \
  database/creds/backend-readonly
```

### Get Dynamic Database Credentials

```bash
# Read generates new credentials each time
vault read engineering/database/creds/backend-readonly

# Output:
# Key                Value
# ---                -----
# lease_id           engineering/database/creds/backend-readonly/xxxxx
# lease_duration     1h
# lease_renewable    true
# password           A1a-xxxxxxxxxxxxxx
# username           v-userpass-backend-readonly-xxxxxx
```

## Terraform Commands

```bash
# Initialize
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# Destroy resources
terraform destroy

# Format code
terraform fmt

# Validate configuration
terraform validate
```

## Architecture

```text
┌──────────────────────────────────────────────────────────────────────┐
│                       Vault Configuration                            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  PKI Certificate Authority                                           │
│  ├── pki/         (Root CA — 10yr, offline signing only)             │
│  └── pki_int/     (Intermediate CA — 5yr, issues certs)             │
│      ├── Role: kubernetes-server  (TLS for K8s services)            │
│      ├── Role: kubernetes-client  (mTLS client certs)               │
│      ├── Role: wildcard           (*.proxcloud.io)                   │
│      └── ACME directory           (/v1/pki_int/acme/directory)      │
│                                                                      │
│  Auth Methods                                                        │
│  ├── userpass/     (Demo users: frontend-dev, backend-dev)          │
│  ├── approle/      (CI/CD: cert-issuer role)                        │
│  └── kubernetes/   (K8s workloads + cert-manager)                   │
│                                                                      │
│  engineering/ (namespace)                                            │
│  ├── frontend-secrets/ (kv-v2)                                      │
│  ├── backend-secrets/  (kv-v2)                                      │
│  └── database/         (optional, dynamic creds)                    │
│                                                                      │
│  Policies                                                            │
│  ├── frontend-engineer   (read frontend KV)                         │
│  ├── backend-engineer    (read backend KV + DB creds)               │
│  ├── pki-issue           (issue/sign certs)                         │
│  └── pki-admin           (full PKI management)                      │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Certificate Flow:
  cert-manager (K8s) ──► K8s Auth ──► Vault PKI Int ──► TLS Cert
  ACME Client         ──► ACME Dir ──► Vault PKI Int ──► TLS Cert
  CI/CD Pipeline      ──► AppRole  ──► Vault PKI Int ──► TLS Cert
```

## PKI Usage Examples

### Issue a server certificate via CLI

```bash
vault write pki_int/issue/kubernetes-server \
  common_name="myapp.proxcloud.io" \
  alt_names="myapp.svc.cluster.local" \
  ttl="720h"
```

### Issue a wildcard certificate

```bash
vault write pki_int/issue/wildcard \
  common_name="*.proxcloud.io" \
  ttl="720h"
```

### Get the CA chain (for trust stores)

```bash
# Root CA
vault read -field=certificate pki/ca/pem > root-ca.pem

# Intermediate CA
vault read -field=certificate pki_int/ca/pem > intermediate-ca.pem

# Full chain
cat intermediate-ca.pem root-ca.pem > ca-chain.pem
```

### cert-manager ClusterIssuer (after K8s auth is enabled)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    path: pki_int/sign/kubernetes-server
    server: http://vault.proxcloud.io:8200
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        serviceAccountRef:
          name: cert-manager
```

### ACME directory (for external ACME clients)

```bash
# ACME directory URL
curl ${VAULT_ADDR}/v1/pki_int/acme/directory
```

## Production Considerations

For production use, consider:

1. **Remote State**: Use S3 + DynamoDB backend

2. **Sensitive Variables**: Use environment variables

   ```bash
   export TF_VAR_vault_token="hvs.xxxxx"
   ```

3. **Strong Passwords**: Replace demo passwords with secure values

4. **Audit Logging**: Enable Vault audit logging

5. **TLS**: Use HTTPS for Vault connections

6. **PKI Best Practices**:
   - Keep root CA offline (only used to sign intermediates)
   - Set short TTLs on leaf certificates (30 days default)
   - Enable CRL / OCSP for revocation
   - Rotate intermediate CA before expiry

7. **Kubernetes Auth**: Enable only after K8s cluster is deployed (stage 03). Update `kubernetes_host` and `kubernetes_ca_cert` with actual values.

## Deployment Sequence

```text
Stage 1: terraform apply                    (PKI + secrets + users)
         ├── Creates engineering namespace
         ├── Creates KV-V2 secrets engines
         ├── Creates PKI Root CA + Intermediate CA
         ├── Creates PKI roles (kubernetes-server, client, wildcard)
         ├── Enables ACME on intermediate CA
         ├── Creates AppRole for CI/CD cert issuance
         └── Creates policies and demo users

Stage 2: After K8s cluster deployed (03-kubernetes)
         ├── Set enable_kubernetes_auth = true
         ├── Populate kubernetes_host and kubernetes_ca_cert
         └── terraform apply (adds K8s auth + cert-manager role)

Stage 3: In K8s cluster
         ├── Install cert-manager
         ├── Create ClusterIssuer pointing to Vault PKI
         └── Request certificates via Certificate resources
```

## Troubleshooting

### Provider authentication failed

```bash
# Verify token is valid
vault token lookup

# Check Vault is accessible
curl $VAULT_ADDR/v1/sys/health
```

### Namespace already exists

```bash
# Import existing namespace
terraform import vault_namespace.engineering engineering
```

### Permission denied

Ensure the token has admin privileges:

```bash
vault token capabilities sys/mounts
# Should include: create, read, update, delete, list
```

## Dependencies

| Provider | Version |
|----------|---------|
| hashicorp/vault | >= 4.0.0 |

## License

Part of the Vault Enterprise Demo. For educational purposes.
