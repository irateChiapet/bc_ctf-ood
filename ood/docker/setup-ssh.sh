#!/bin/bash
set -e

echo "Setting up SSH configuration for Shell app..."

# Create SSH directory
mkdir -p /etc/ssh/ssh_config.d
mkdir -p /var/www/ood/.ssh

# Create SSH client configuration for compute nodes
cat > /etc/ssh/ssh_config.d/ood_shell.conf << 'SSHEOF'
Host 10.11.12.*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    PasswordAuthentication yes
    PubkeyAuthentication yes
    PreferredAuthentications publickey,password
    ConnectTimeout 10
SSHEOF

# Set proper permissions
chmod 644 /etc/ssh/ssh_config.d/ood_shell.conf
chown -R apache:apache /var/www/ood/.ssh 2>/dev/null || true
chmod 700 /var/www/ood/.ssh 2>/dev/null || true

echo "SSH configuration completed"
