#!/bin/bash
set -e

# Build script specifically for shell app in development/maintenance scenarios

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SHELL BUILD: $1"
}

SHELL_DIR="/var/www/ood/apps/sys/shell"

log "Building OnDemand Shell App..."

if [ ! -d "$SHELL_DIR" ]; then
    log "ERROR: Shell app directory not found at $SHELL_DIR"
    exit 1
fi

cd "$SHELL_DIR"

# Check if we're running as root or have proper permissions
if [ "$EUID" -ne 0 ] && [ ! -w "$SHELL_DIR" ]; then
    log "ERROR: Insufficient permissions to build shell app"
    exit 1
fi

# Backup existing node_modules if present
if [ -d "node_modules" ]; then
    log "Backing up existing node_modules..."
    mv node_modules node_modules.backup.$(date +%s)
fi

log "Installing build dependencies..."

# Ensure we have the required build tools
if ! command -v gcc > /dev/null 2>&1; then
    log "ERROR: gcc not found. Install build tools first:"
    log "  dnf install -y gcc-c++ make python3-devel"
    exit 1
fi

if ! command -v node > /dev/null 2>&1; then
    log "ERROR: Node.js not found"
    exit 1
fi

# Install yarn locally
log "Installing yarn..."
npm install --production --prefix tmp yarn

# Install shell app dependencies
log "Installing shell app dependencies..."
tmp/node_modules/yarn/bin/yarn install --production --frozen-lockfile --ignore-engines

# Clean up
log "Cleaning up temporary files..."
rm -rf tmp

# Set proper permissions
log "Setting permissions..."
chown -R apache:apache node_modules 2>/dev/null || chown -R $USER:$USER node_modules
chmod -R 755 node_modules

# Verify the build
if [ -f "node_modules/node-pty/build/Release/pty.node" ]; then
    log "✅ Shell app built successfully!"
    log "✅ node-pty native module compiled"
else
    log "❌ Build failed - node-pty native module not found"
    exit 1
fi

# Test basic functionality
log "Testing shell app basic functionality..."
if node -e "require('node-pty')" 2>/dev/null; then
    log "✅ node-pty module loads correctly"
else
    log "❌ node-pty module failed to load"
    exit 1
fi

log "🎉 Shell app build completed successfully!"
log "The shell app is ready for use at $SHELL_DIR"