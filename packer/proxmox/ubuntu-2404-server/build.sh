#!/bin/bash
# Local Packer Build Script for Proxmox Ubuntu 24.04 Template
# Run this from a machine with network access to your Proxmox server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for required tools
check_requirements() {
  log_info "Checking requirements..."

  if ! command -v packer &>/dev/null; then
    log_error "Packer is not installed. Install from: https://developer.hashicorp.com/packer/downloads"
    exit 1
  fi

  log_info "Packer version: $(packer version | head -1)"
}

# Load environment variables from secrets file
load_secrets() {
  if [ -f "secrets.pkrvars.hcl" ]; then
    log_info "Found secrets.pkrvars.hcl"
    VAR_FILE="-var-file=secrets.pkrvars.hcl"
  elif [ -f ".env" ]; then
    log_info "Loading secrets from .env file"
    # shellcheck disable=SC2046
    export $(grep -v '^#' .env | xargs)
    VAR_FILE=""
  else
    log_warn "No secrets file found. Set environment variables or create secrets.pkrvars.hcl"
    log_info "Required variables:"
    log_info "  - PROXMOX_API_URL or proxmox_api_url"
    log_info "  - PROXMOX_API_TOKEN_ID or proxmox_api_token_id"
    log_info "  - PROXMOX_API_TOKEN_SECRET or proxmox_api_token_secret"
    log_info "  - SSH_PASSWORD or ssh_password (optional, default: packer)"
    VAR_FILE=""
  fi
}

# Build variable arguments from environment
build_var_args() {
  VAR_ARGS=""

  if [ -n "$PROXMOX_API_URL" ]; then
    VAR_ARGS="$VAR_ARGS -var proxmox_api_url=$PROXMOX_API_URL"
  fi
  if [ -n "$PROXMOX_API_TOKEN_ID" ]; then
    VAR_ARGS="$VAR_ARGS -var proxmox_api_token_id=$PROXMOX_API_TOKEN_ID"
  fi
  if [ -n "$PROXMOX_API_TOKEN_SECRET" ]; then
    VAR_ARGS="$VAR_ARGS -var proxmox_api_token_secret=$PROXMOX_API_TOKEN_SECRET"
  fi
  if [ -n "$SSH_PASSWORD" ]; then
    VAR_ARGS="$VAR_ARGS -var ssh_password=$SSH_PASSWORD"
  fi
  if [ -n "$PROXMOX_NODE" ]; then
    VAR_ARGS="$VAR_ARGS -var proxmox_node=$PROXMOX_NODE"
  fi
}

# Test Proxmox connectivity
test_connectivity() {
  log_info "Testing Proxmox connectivity..."

  # Extract host from URL
  if [ -n "$PROXMOX_API_URL" ]; then
    PROXMOX_HOST=$(echo "$PROXMOX_API_URL" | sed 's|https\?://||' | cut -d':' -f1 | cut -d'/' -f1)

    if ping -c 1 -W 3 "$PROXMOX_HOST" &>/dev/null; then
      log_info "✓ Proxmox host $PROXMOX_HOST is reachable"
    else
      log_warn "Cannot ping $PROXMOX_HOST (firewall may block ICMP)"
    fi

    # Test API endpoint
    if curl -sk --connect-timeout 5 "$PROXMOX_API_URL" &>/dev/null; then
      log_info "✓ Proxmox API is accessible"
    else
      log_error "Cannot reach Proxmox API at $PROXMOX_API_URL"
      exit 1
    fi
  fi
}

# Initialize Packer
packer_init() {
  log_info "Initializing Packer plugins..."
  packer init .
}

# Validate template
packer_validate() {
  log_info "Validating Packer template..."
  packer validate $VAR_FILE $VAR_ARGS . 2>/dev/null || packer validate -syntax-only .
}

# Build image
packer_build() {
  log_info "Starting Packer build..."
  log_info "This may take 10-20 minutes..."

  # Add -on-error=ask for debugging, or -force to overwrite existing templates
  PACKER_LOG=${PACKER_LOG:-0} packer build -force $VAR_FILE $VAR_ARGS .
}

# Main
main() {
  echo "=============================================="
  echo "  Packer Build: Ubuntu 24.04 for Proxmox"
  echo "=============================================="
  echo ""

  check_requirements
  load_secrets
  build_var_args

  case "${1:-build}" in
    init)
      packer_init
      ;;
    validate)
      packer_init
      packer_validate
      ;;
    test)
      test_connectivity
      ;;
    build)
      test_connectivity
      packer_init
      packer_validate
      packer_build
      ;;
    debug)
      export PACKER_LOG=1
      test_connectivity
      packer_init
      packer_build
      ;;
    *)
      echo "Usage: $0 [init|validate|test|build|debug]"
      echo ""
      echo "Commands:"
      echo "  init      - Initialize Packer plugins"
      echo "  validate  - Validate template syntax"
      echo "  test      - Test Proxmox connectivity"
      echo "  build     - Full build (default)"
      echo "  debug     - Build with verbose logging"
      exit 1
      ;;
  esac

  log_info "Done!"
}

main "$@"
