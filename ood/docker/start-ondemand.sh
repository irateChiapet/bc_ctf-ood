#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting OpenOnDemand container..."

# Process OOD portal config template with environment variables
if [ -f "/etc/ood/config/ood_portal.yml.template" ]; then
    log "Processing OOD portal configuration template..."
    envsubst < /etc/ood/config/ood_portal.yml.template > /etc/ood/config/ood_portal.yml
    log "OOD portal configuration template processed"
fi

# Generate OOD portal config if it exists
if [ -f "/etc/ood/config/ood_portal.yml" ]; then
    log "Generating OOD portal configuration..."
    /opt/ood/ood-portal-generator/sbin/update_ood_portal
    log "OOD portal configuration generated"
fi

# Fix permissions for shell app to read cluster configurations
log "Setting permissions for cluster configurations..."
chmod 644 /etc/ood/config/clusters.d/* 2>/dev/null || true

# Validate shell app installation
log "Validating shell app installation..."
if [ -d "/var/www/ood/apps/sys/shell/node_modules" ]; then
    log "Shell app dependencies found"
    if [ -d "/var/www/ood/apps/sys/shell/node_modules/node-pty" ]; then
        log "Shell app is properly configured with node-pty"
    else
        log "WARNING: node-pty not found in shell app dependencies"
    fi
else
    log "WARNING: Shell app dependencies not found"
fi

# Start httpd in foreground mode
log "Starting Apache HTTP Server..."
exec /usr/sbin/httpd -D FOREGROUND