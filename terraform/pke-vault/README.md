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

Reference: [HashiCorp Vault on Kubernetes with TLS](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls)

### Vault Prerequisites

Install required tools via Homebrew:

```bash
brew install kubectl helm jq
```

### Step 1: Add Vault Helm Repository

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm search repo hashicorp/vault
```

### Step 2: Create Working Directory and Export Variables

```bash
mkdir /tmp/vault

export VAULT_K8S_NAMESPACE="vault"
export VAULT_HELM_RELEASE_NAME="vault"
export VAULT_SERVICE_NAME="vault-internal"
export K8S_CLUSTER_NAME="cluster.local"
export WORKDIR=/tmp/vault
```

### Step 3: Generate Private Key and Certificate Signing Request

Generate the RSA private key:

```bash
openssl genrsa -out ${WORKDIR}/vault.key 2048
```

Create the CSR configuration file:

```bash
cat > ${WORKDIR}/vault-csr.conf <<EOF
[req]
default_bits = 2048
prompt = no
encrypt_key = yes
default_md = sha256
distinguished_name = kubelet_serving
req_extensions = v3_req
[ kubelet_serving ]
O = system:nodes
CN = system:node:*.${VAULT_K8S_NAMESPACE}.svc.${K8S_CLUSTER_NAME}
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.${VAULT_SERVICE_NAME}
DNS.2 = *.${VAULT_SERVICE_NAME}.${VAULT_K8S_NAMESPACE}.svc.${K8S_CLUSTER_NAME}
DNS.3 = *.${VAULT_K8S_NAMESPACE}
IP.1 = 127.0.0.1
EOF
```

Generate the CSR:

```bash
openssl req -new -key ${WORKDIR}/vault.key \
  -out ${WORKDIR}/vault.csr \
  -config ${WORKDIR}/vault-csr.conf
```

### Step 4: Create Kubernetes Certificate Signing Request

Create and submit the CSR:

```bash
cat > ${WORKDIR}/csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
   name: vault.svc
spec:
   signerName: kubernetes.io/kubelet-serving
   expirationSeconds: 8640000
   request: $(cat ${WORKDIR}/vault.csr | base64 | tr -d '\n')
   usages:
   - digital signature
   - key encipherment
   - server auth
EOF

kubectl create -f ${WORKDIR}/csr.yaml
kubectl certificate approve vault.svc
kubectl get csr vault.svc
```

### Step 5: Store Certificates in Kubernetes Secrets

Retrieve the issued certificate:

```bash
kubectl get csr vault.svc -o jsonpath='{.status.certificate}' | \
  openssl base64 -d -A -out ${WORKDIR}/vault.crt
```

Retrieve the Kubernetes CA certificate (macOS compatible):

```bash
kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[].cluster.certificate-authority-data}' \
  | base64 --decode > ${WORKDIR}/vault.ca
```

Create the namespace and TLS secret:

```bash
kubectl create namespace $VAULT_K8S_NAMESPACE

kubectl create secret generic vault-ha-tls \
  -n $VAULT_K8S_NAMESPACE \
  --from-file=vault.key=${WORKDIR}/vault.key \
  --from-file=vault.crt=${WORKDIR}/vault.crt \
  --from-file=vault.ca=${WORKDIR}/vault.ca
```

### Step 6: Deploy Vault via Helm with TLS and HA

Create the Helm overrides file:

```bash
cat > ${WORKDIR}/overrides.yaml <<EOF
global:
   enabled: true
   tlsDisable: false
injector:
   enabled: true
server:
   extraEnvironmentVars:
      VAULT_CACERT: /vault/userconfig/vault-ha-tls/vault.ca
      VAULT_TLSCERT: /vault/userconfig/vault-ha-tls/vault.crt
      VAULT_TLSKEY: /vault/userconfig/vault-ha-tls/vault.key
   volumes:
      - name: userconfig-vault-ha-tls
        secret:
          defaultMode: 420
          secretName: vault-ha-tls
   volumeMounts:
      - mountPath: /vault/userconfig/vault-ha-tls
        name: userconfig-vault-ha-tls
        readOnly: true
   standalone:
      enabled: false
   affinity: ""
   ha:
      enabled: true
      replicas: 3
      raft:
         enabled: true
         setNodeId: true
         config: |
            cluster_name = "vault-integrated-storage"
            ui = true
            listener "tcp" {
               tls_disable = 0
               address = "[::]:8200"
               cluster_address = "[::]:8201"
               tls_cert_file = "/vault/userconfig/vault-ha-tls/vault.crt"
               tls_key_file  = "/vault/userconfig/vault-ha-tls/vault.key"
               tls_client_ca_file = "/vault/userconfig/vault-ha-tls/vault.ca"
            }
            storage "raft" {
               path = "/vault/data"
            }
            disable_mlock = true
            service_registration "kubernetes" {}
EOF
```

Deploy Vault:

```bash
helm install -n $VAULT_K8S_NAMESPACE $VAULT_HELM_RELEASE_NAME \
  hashicorp/vault -f ${WORKDIR}/overrides.yaml
```

Verify pods are running (vault-0/1/2 will show `0/1 Running` until initialized):

```bash
kubectl -n $VAULT_K8S_NAMESPACE get pods
```

### Step 7: Initialize and Unseal Vault

Initialize vault-0 with a single unseal key:

```bash
kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > ${WORKDIR}/cluster-keys.json
```

> **Note:** For production, use more key shares (e.g., `-key-shares=5 -key-threshold=3`).

Extract the unseal key and unseal vault-0:

```bash
VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" ${WORKDIR}/cluster-keys.json)

kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- \
  vault operator unseal $VAULT_UNSEAL_KEY
```

### Step 8: Join Additional Nodes to the Raft Cluster

Join and unseal vault-1:

```bash
kubectl exec -n $VAULT_K8S_NAMESPACE -it vault-1 -- /bin/sh -c '
vault operator raft join \
  -address=https://vault-1.vault-internal:8200 \
  -leader-ca-cert="$(cat /vault/userconfig/vault-ha-tls/vault.ca)" \
  -leader-client-cert="$(cat /vault/userconfig/vault-ha-tls/vault.crt)" \
  -leader-client-key="$(cat /vault/userconfig/vault-ha-tls/vault.key)" \
  https://vault-0.vault-internal:8200'

kubectl exec -n $VAULT_K8S_NAMESPACE vault-1 -- \
  vault operator unseal $VAULT_UNSEAL_KEY
```

Join and unseal vault-2:

```bash
kubectl exec -n $VAULT_K8S_NAMESPACE -it vault-2 -- /bin/sh -c '
vault operator raft join \
  -address=https://vault-2.vault-internal:8200 \
  -leader-ca-cert="$(cat /vault/userconfig/vault-ha-tls/vault.ca)" \
  -leader-client-cert="$(cat /vault/userconfig/vault-ha-tls/vault.crt)" \
  -leader-client-key="$(cat /vault/userconfig/vault-ha-tls/vault.key)" \
  https://vault-0.vault-internal:8200'

kubectl exec -n $VAULT_K8S_NAMESPACE vault-2 -- \
  vault operator unseal $VAULT_UNSEAL_KEY
```

### Step 9: Verify Cluster Status

Login and check the Raft cluster:

```bash
export CLUSTER_ROOT_TOKEN=$(jq -r ".root_token" ${WORKDIR}/cluster-keys.json)

kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- \
  vault login $CLUSTER_ROOT_TOKEN

kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- \
  vault operator raft list-peers

kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault status
```

### Step 10: Create and Test a Secret

```bash
kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- vault secrets enable -path=secret kv-v2

kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- \
  vault kv put secret/tls/apitest username="apiuser" password="supersecret"

kubectl exec -n $VAULT_K8S_NAMESPACE vault-0 -- \
  vault kv get secret/tls/apitest
```

### Step 11: Access Vault via API

Port-forward the service (run in a separate terminal):

```bash
kubectl -n vault port-forward service/vault 8200:8200
```

Retrieve the secret via HTTPS API:

```bash
curl --cacert $WORKDIR/vault.ca \
  --header "X-Vault-Token: $CLUSTER_ROOT_TOKEN" \
  https://127.0.0.1:8200/v1/secret/data/tls/apitest | jq .data.data
```

### Cleanup

```bash
rm -r $WORKDIR
```
