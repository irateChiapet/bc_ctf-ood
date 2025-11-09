#!/bin/bash
set -e

echo "Setting up users and OOD configuration..."

# Set defaults for environment variables
export HOSTNAME=${HOSTNAME:-192.168.1.69}
export KEYCLOAK_HTTP_PORT=${KEYCLOAK_HTTP_PORT:-8080}
export OIDC_CLIENT_SECRET=${OIDC_CLIENT_SECRET:-ondemand-secret-123}
export OIDC_CRYPTO_PASSPHRASE=${OIDC_CRYPTO_PASSPHRASE:-openondemand-crypto-passphrase-change-me}

echo "Configuration:"
echo "  HOSTNAME: $HOSTNAME"
echo "  KEYCLOAK_HTTP_PORT: $KEYCLOAK_HTTP_PORT"

# User setup (previous code)
cp /etc/passwd /etc/passwd.bak 2>/dev/null || true
cp /etc/shadow /etc/shadow.bak 2>/dev/null || true
cp /etc/group /etc/group.bak 2>/dev/null || true

if [ -f /tmp/template_passwd ]; then
    cat /tmp/template_passwd >> /etc/passwd
    echo "Added $(wc -l < /tmp/template_passwd) users"
fi

if [ -f /tmp/template_shadow ]; then
    cat /tmp/template_shadow >> /etc/shadow
fi

if [ -f /tmp/template_group ]; then
    cat /tmp/template_group >> /etc/group
fi

if ! getent group shadow > /dev/null 2>&1; then
    groupadd -r shadow
fi

chmod 644 /etc/passwd /etc/group
chmod 640 /etc/shadow
chown root:shadow /etc/shadow

# Create home directories
while IFS=: read -r username password uid gid gecos homedir shell; do
    if [[ -n "$username" && ! "$username" =~ ^[[:space:]]*# ]]; then
        if [ ! -d "$homedir" ]; then
            mkdir -p "$homedir"
            chown "$uid:$gid" "$homedir" 2>/dev/null || true
            chmod 755 "$homedir"
        fi
    fi
done < /tmp/template_passwd 2>/dev/null || true

echo "User setup completed!"

# Configure OOD Portal
echo "Configuring OOD portal..."

# Ensure OIDC module is loaded
if [ -f "/usr/lib64/httpd/modules/mod_auth_openidc.so" ]; then
    echo "LoadModule auth_openidc_module modules/mod_auth_openidc.so" > /etc/httpd/conf.modules.d/10-auth_openidc.conf
    echo "OIDC module configured"
else
    echo "ERROR: mod_auth_openidc not found!"
    exit 1
fi

# Process portal template
if [ -f "/etc/ood/config/ood_portal.yml.template" ]; then
    echo "Processing portal template..."
    envsubst < /etc/ood/config/ood_portal.yml.template > /etc/ood/config/ood_portal.yml
    
    echo "Generated portal config:"
    cat /etc/ood/config/ood_portal.yml
    
    # Generate Apache configuration
    echo "Generating Apache configuration..."
    /opt/ood/ood-portal-generator/sbin/update_ood_portal
    
    echo "Testing Apache configuration..."
    httpd -t
    
    echo "OOD configuration completed!"
else
    echo "ERROR: Portal template not found!"
    exit 1
fi

# Configure SSH for Shell app
echo "Setting up SSH for Shell app..."
bash /usr/local/bin/setup-ssh.sh || echo "SSH setup completed with warnings"

# Fix OOD config directory permissions for Shell app
echo "Setting proper permissions for OOD config directories..."
chmod 755 /etc/ood/config/
chmod 755 /etc/ood/config/clusters.d/
chmod 644 /etc/ood/config/clusters.d/* 2>/dev/null || true

echo "OOD config permissions fixed"

