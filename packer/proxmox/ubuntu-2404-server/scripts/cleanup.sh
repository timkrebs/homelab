#!/bin/bash
set -e

echo ">>> Starting cleanup for template conversion..."

# Clean apt cache
sudo apt-get clean
sudo apt-get autoremove -y

# Remove machine-id (regenerated on clone)
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id

# Clear cloud-init state
sudo cloud-init clean --logs

# Remove SSH host keys (regenerated on first boot)
sudo rm -f /etc/ssh/ssh_host_*

# Clear logs
sudo truncate -s 0 /var/log/*.log
sudo truncate -s 0 /var/log/**/*.log 2>/dev/null || true
sudo rm -rf /var/log/journal/*

# Clear tmp
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear bash history
cat /dev/null >~/.bash_history
history -c

# Remove packer user authorized_keys
sudo rm -f /home/packer/.ssh/authorized_keys

echo ">>> Cleanup complete - ready for template conversion"
