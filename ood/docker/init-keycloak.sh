#!/bin/bash
set -e

echo "Starting Keycloak with SSL..."

# Process realm template
substitute_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ -f "$template_file" ]; then
        echo "Processing template: $template_file -> $output_file"
        local sed_script=""
        for var in HOSTNAME OIDC_CLIENT_SECRET; do
            if [ ! -z "${!var}" ]; then
                sed_script="${sed_script}s/\${${var}}/${!var}/g; "
            fi
        done
        
        if [ ! -z "$sed_script" ]; then
            sed "$sed_script" "$template_file" > "$output_file"
        else
            cp "$template_file" "$output_file"
        fi
        echo "Template processed successfully"
    fi
}

REALM_TEMPLATE="/opt/keycloak/data/import/realm-import.json.template"
REALM_OUTPUT="/opt/keycloak/data/import/realm-import.json"

if [ -f "$REALM_TEMPLATE" ]; then
    substitute_template "$REALM_TEMPLATE" "$REALM_OUTPUT"
fi

# Start Keycloak with SSL
echo "Starting Keycloak with HTTPS on port 8443..."
/opt/keycloak/bin/kc.sh start \
    --import-realm \
    --https-port=8443 \
    --https-certificate-file=/opt/keycloak/conf/server.crt.pem \
    --https-certificate-key-file=/opt/keycloak/conf/server.key.pem \
    --hostname=${HOSTNAME} \
    --hostname-strict=false &

KEYCLOAK_PID=$!

cleanup() {
    echo "Shutting down Keycloak..."
    kill $KEYCLOAK_PID 2>/dev/null || true
    wait $KEYCLOAK_PID 2>/dev/null || true
}
trap cleanup EXIT

# Wait for Keycloak HTTPS
sleep 10

# Run user creation if Keycloak is ready
if [ -f "/opt/keycloak/bin/add-users-keycloak.sh" ]; then
    echo "Running user creation..."
    KC_HTTPS_PORT=8443 bash /opt/keycloak/bin/add-users-keycloak.sh
fi

echo "Keycloak SSL initialization completed!"
wait $KEYCLOAK_PID
