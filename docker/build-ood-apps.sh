#!/bin/bash
set -e

echo "Installing custom OOD apps..."

# Create user apps directory if it doesn't exist
mkdir -p /var/www/ood/apps/usr

# Function to install a Node.js app
install_nodejs_app() {
    local app_name=$1
    local source_dir="/tmp/ood-apps/${app_name}"
    local target_dir="/var/www/ood/apps/usr/${app_name}"
    
    if [ -d "$source_dir" ]; then
        echo "Installing ${app_name} app..."
        
        # Copy app files
        cp -r "$source_dir" "$target_dir"
        
        # Set ownership
        chown -R apache:apache "$target_dir"
        chmod -R 755 "$target_dir"
        
        # Install Node.js dependencies if package.json exists
        if [ -f "$target_dir/package.json" ]; then
            echo "Installing Node.js dependencies for ${app_name}..."
            cd "$target_dir"
            npm install --production
            chown -R apache:apache node_modules 2>/dev/null || true
        fi
        
        echo "${app_name} app installed successfully"
    else
        echo "Warning: ${app_name} app source not found at $source_dir"
    fi
}

# Install all custom apps
install_nodejs_app "diskspace"

echo "Custom OOD apps installation completed"
