.PHONY: help init validate plan apply packer-validate packer-build packer-remote-build packer-remote-setup lint clean pre-commit pre-commit-install pre-commit-update pre-commit-check flux-bootstrap k8s-validate

# Configuration - override with environment variables or make arguments
PROXMOX_HOST ?= root@192.168.1.128
PROXMOX_PACKER_DIR ?= /root/packer
TEMPLATE ?= ubuntu-2404-server

# Default target
help:
	@echo "Proxmox Homelab - Available targets:"
	@echo ""
	@echo "  Terraform:"
	@echo "    init              - Initialize Terraform workspaces"
	@echo "    validate          - Validate Terraform configuration"
	@echo "    plan              - Plan all stacks"
	@echo "    apply             - Apply all stacks (requires confirmation)"
	@echo ""
	@echo "  Packer:"
	@echo "    packer-validate   - Validate Packer templates locally"
	@echo "    packer-remote-setup - Setup Packer on Proxmox host (one-time)"
	@echo "    packer-remote-build - Build image on Proxmox host (recommended)"
	@echo "                          TEMPLATE=ubuntu-2404-server (default)"
	@echo "                          PROXMOX_HOST=root@192.168.1.128 (default)"
	@echo ""
	@echo "  Development:"
	@echo "    lint              - Run all linters"
	@echo "    pre-commit        - Run pre-commit hooks on all files"
	@echo "    pre-commit-install- Install pre-commit hooks"
	@echo "    pre-commit-update - Update pre-commit hook versions"
	@echo "    pre-commit-check  - Check pre-commit dependencies"
	@echo "    clean             - Clean temporary files"
	@echo ""
	@echo "  Kubernetes:"
	@echo "    flux-bootstrap    - Bootstrap Flux GitOps"
	@echo "    k8s-validate      - Validate Kubernetes manifests"

# Terraform targets
init:
	@echo "Initializing Terraform workspaces..."
	@for stack in 01-infrastructure 02-kubernetes 03-platform 04-applications; do \
		echo ">>> Initializing $$stack"; \
		cd terraform/stacks/$$stack && terraform init && cd ../../..; \
	done

validate:
	@echo "Validating Terraform configuration..."
	@for stack in 01-infrastructure 02-kubernetes 03-platform 04-applications; do \
		echo ">>> Validating $$stack"; \
		cd terraform/stacks/$$stack && terraform validate && cd ../../..; \
	done

plan:
	@echo "Planning Terraform changes..."
	@for stack in 01-infrastructure 02-kubernetes 03-platform 04-applications; do \
		echo ">>> Planning $$stack"; \
		cd terraform/stacks/$$stack && terraform plan && cd ../../..; \
	done

apply:
	@echo "Applying Terraform changes..."
	@read -p "Are you sure you want to apply all stacks? [y/N] " confirm && \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		for stack in 01-infrastructure 02-kubernetes 03-platform 04-applications; do \
			echo ">>> Applying $$stack"; \
			cd terraform/stacks/$$stack && terraform apply && cd ../../..; \
		done \
	fi

# Packer targets
packer-validate:
	@echo "Validating Packer templates..."
	@for template in packer/proxmox/*/; do \
		if [ -f "$$template"/*.pkr.hcl ]; then \
			echo ">>> Validating $$template"; \
			packer init "$$template" && packer validate -syntax-only "$$template"; \
		fi \
	done

packer-build:
	@echo "Building Packer images locally..."
	@echo "WARNING: This requires network access to Proxmox. Use 'make packer-remote-build' instead."
	@read -p "Which template? [ubuntu-2404-server]: " template && \
	template=$${template:-ubuntu-2404-server} && \
	cd packer/proxmox/$$template && packer init . && packer build -var-file=secrets.pkrvars.hcl .

# Remote Packer build - runs directly on Proxmox host
packer-remote-setup:
	@echo "Setting up Packer on Proxmox host $(PROXMOX_HOST)..."
	ssh $(PROXMOX_HOST) 'mkdir -p $(PROXMOX_PACKER_DIR)'
	@echo "Installing Packer on Proxmox..."
	ssh $(PROXMOX_HOST) 'command -v packer || (apt-get update && apt-get install -y gnupg software-properties-common && \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
		echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" > /etc/apt/sources.list.d/hashicorp.list && \
		apt-get update && apt-get install -y packer xorriso)'
	@echo "Setup complete! Now run: make packer-remote-build"

packer-remote-build:
	@echo "Building $(TEMPLATE) on Proxmox host $(PROXMOX_HOST)..."
	@echo ""
	@echo "Step 1: Syncing Packer files to Proxmox..."
	rsync -avz --delete \
		packer/proxmox/$(TEMPLATE)/ \
		$(PROXMOX_HOST):$(PROXMOX_PACKER_DIR)/$(TEMPLATE)/
	@echo ""
	@echo "Step 2: Running Packer build on Proxmox..."
	ssh -t $(PROXMOX_HOST) 'cd $(PROXMOX_PACKER_DIR)/$(TEMPLATE) && \
		TOKEN=$$(grep "root@pam!packer" /etc/pve/priv/token.cfg 2>/dev/null | cut -d" " -f2) && \
		if [ -z "$$TOKEN" ]; then \
			echo "Creating API token..."; \
			pveum user token add root@pam packer --privsep=0 2>/dev/null || true; \
			TOKEN=$$(grep "root@pam!packer" /etc/pve/priv/token.cfg | cut -d" " -f2); \
		fi && \
		echo "Using token: root@pam!packer" && \
		packer init . && \
		PACKER_LOG=1 packer build -force \
			-var "proxmox_api_token_secret=$$TOKEN" \
			.'
	@echo ""
	@echo "Build complete! Template should now be available in Proxmox."

# Development targets
lint:
	@echo "Running linters..."
	terraform fmt -recursive
	packer fmt -recursive packer/

pre-commit-install:
	@echo "Installing pre-commit hooks..."
	@command -v pre-commit >/dev/null 2>&1 || { echo "Installing pre-commit..."; pip install pre-commit; }
	pre-commit install
	pre-commit install --hook-type commit-msg
	@echo "Pre-commit hooks installed successfully!"

pre-commit-update:
	@echo "Updating pre-commit hooks..."
	pre-commit autoupdate

pre-commit:
	pre-commit run --all-files

pre-commit-check:
	@echo "Checking pre-commit dependencies..."
	@command -v pre-commit >/dev/null 2>&1 && echo "[OK] pre-commit" || echo "[MISSING] pre-commit (pip install pre-commit)"
	@command -v terraform >/dev/null 2>&1 && echo "[OK] terraform" || echo "[MISSING] terraform"
	@command -v packer >/dev/null 2>&1 && echo "[OK] packer" || echo "[MISSING] packer"
	@command -v tflint >/dev/null 2>&1 && echo "[OK] tflint" || echo "[MISSING] tflint (brew install tflint)"
	@command -v trivy >/dev/null 2>&1 && echo "[OK] trivy" || echo "[MISSING] trivy (brew install trivy)"
	@command -v kubeconform >/dev/null 2>&1 && echo "[OK] kubeconform" || echo "[MISSING] kubeconform (brew install kubeconform)"
	@command -v shellcheck >/dev/null 2>&1 && echo "[OK] shellcheck" || echo "[MISSING] shellcheck (brew install shellcheck)"
	@command -v shfmt >/dev/null 2>&1 && echo "[OK] shfmt" || echo "[MISSING] shfmt (brew install shfmt)"
	@command -v gitleaks >/dev/null 2>&1 && echo "[OK] gitleaks" || echo "[MISSING] gitleaks (brew install gitleaks)"

clean:
	@echo "Cleaning temporary files..."
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	find . -type d -name "packer_cache" -exec rm -rf {} + 2>/dev/null || true

# Kubernetes targets
flux-bootstrap:
	@echo "Bootstrapping Flux..."
	@read -p "GitHub organization/user: " owner && \
	read -p "Repository name: " repo && \
	flux bootstrap github \
		--owner=$$owner \
		--repository=$$repo \
		--branch=main \
		--path=kubernetes/clusters/homelab \
		--personal

flux-check:
	@echo "Checking Flux prerequisites..."
	flux check --pre

flux-reconcile:
	@echo "Reconciling Flux..."
	flux reconcile source git flux-system
	flux reconcile kustomization flux-system

k8s-validate:
	@echo "Validating Kubernetes manifests..."
	@echo ">>> Validating infrastructure manifests..."
	@kubectl apply --dry-run=client -k kubernetes/infrastructure/ 2>/dev/null || \
		kubeconform -strict -ignore-missing-schemas -summary kubernetes/infrastructure/
	@echo ">>> Validating apps manifests..."
	@for app in kubernetes/apps/*/; do \
		echo ">>> Validating $$app"; \
		kubectl apply --dry-run=client -k "$$app" 2>/dev/null || \
		kubeconform -strict -ignore-missing-schemas -summary "$$app"; \
	done
	kubectl apply --dry-run=client -k kubernetes/apps/monitoring/
