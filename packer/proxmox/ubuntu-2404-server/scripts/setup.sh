#!/bin/bash
set -e

echo ">>> Starting base setup..."

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install common packages
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common

# Configure timezone
sudo timedatectl set-timezone UTC

# Enable and start qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent || true

echo ">>> Base setup complete"
