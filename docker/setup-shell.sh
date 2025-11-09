#!/bin/bash
set -e

# Shell app setup script for container build
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SHELL SETUP: $1"
}

log "Starting shell app setup..."

cd /var/www/ood/apps/sys/shell

# Clean any existing node_modules
if [ -d "node_modules" ]; then
    log "Removing existing node_modules..."
    rm -rf node_modules
fi

# Install yarn locally first
log "Installing yarn locally..."
npm install --production --prefix tmp yarn

# Use local yarn to install shell app dependencies
log "Installing shell app dependencies with yarn..."
tmp/node_modules/yarn/bin/yarn install --production --ignore-engines

# Clean up temporary yarn installation
log "Cleaning up temporary yarn installation..."
rm -rf tmp

# Set proper permissions
log "Setting permissions for shell app..."
chown -R apache:apache node_modules
chmod -R 755 node_modules

# Verify installation
if [ -d "node_modules/node-pty" ]; then
    log "Shell app dependencies installed successfully!"
else
    log "ERROR: node-pty not found after installation"
    exit 1
fi

log "Shell app setup completed successfully!"
