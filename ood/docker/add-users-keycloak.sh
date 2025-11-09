#!/bin/bash
set -e

KEYCLOAK_PORT=${KC_HTTPS_PORT:-8443}
REALM_NAME="ondemand"
PLAINTEXT_FILE="/root/plaintext"

echo "Starting Keycloak user creation using HTTPS on port ${KEYCLOAK_PORT}..."

# Function to generate random password
generate_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12
}

# Wait for Keycloak HTTPS to be ready
echo "Waiting for Keycloak HTTPS to be ready...#############"
sleep 10 

# Configure kcadm.sh with HTTPS
echo "Configuring kcadm.sh with admin credentials via HTTPS..."
/opt/keycloak/bin/kcadm.sh config credentials \
    --server "https://192.168.1.69:${KEYCLOAK_PORT}" \
    --realm master \
    --user "${KEYCLOAK_ADMIN}" \
    --password "${KEYCLOAK_ADMIN_PASSWORD}" \
    --insecure

if [ $? -ne 0 ]; then
    echo "Failed to configure kcadm.sh credentials"
    exit 1
fi

echo "Successfully configured kcadm.sh"

# Initialize plaintext password file
echo "# Keycloak User Passwords - Generated on $(date)" > "$PLAINTEXT_FILE"
echo "# Format: username:password" >> "$PLAINTEXT_FILE"
echo "" >> "$PLAINTEXT_FILE"

# Process users from passwd template file
if [ -f /opt/keycloak/templates/passwd ]; then
    echo "Processing users from passwd template..."
    
    created_count=0
    updated_count=0
    failed_count=0
    
    while IFS=: read -r username password uid gid gecos homedir shell; do
        # Skip system users (UID < 1000) and empty lines
        if [[ -z "$username" || "$username" =~ ^[[:space:]]*# || "$uid" -lt 1000 ]]; then
            continue
        fi
        
        # Generate random password
        user_password=$(generate_password)
        
        # Extract name information from gecos field
        if [ -n "$gecos" ]; then
            fullname=$(echo "$gecos" | cut -d',' -f1)
            firstname=$(echo "$fullname" | cut -d' ' -f1)
            lastname=$(echo "$fullname" | cut -d' ' -f2-)
            if [ -z "$lastname" ]; then
                lastname="$firstname"
            fi
            jobtitle=$(echo "$gecos" | cut -d',' -f2- | sed 's/^,*//')
        else
            firstname="$username"
            lastname="User"
            jobtitle=""
        fi
        
        # Set email
        email="${username}@${HOSTNAME:-localhost}"
        
        echo "Processing user: $username ($firstname $lastname) - $jobtitle"
        
        # Check if user already exists
        existing_user_id=$(/opt/keycloak/bin/kcadm.sh get users -r "${REALM_NAME}" --query username="${username}" --fields id 2>/dev/null | grep '"id"' | cut -d'"' -f4)
        
        if [ -n "$existing_user_id" ]; then
            echo "  User exists (ID: $existing_user_id), updating password..."
            
            # Update password using reset-password
            if /opt/keycloak/bin/kcadm.sh update users/${existing_user_id}/reset-password -r "${REALM_NAME}" \
                -s type=password -s value="${user_password}" -s temporary=false -n 2>/dev/null; then
                password_success=true
            else
                password_success=false
            fi
            
            # Update user attributes
            /opt/keycloak/bin/kcadm.sh update users/${existing_user_id} -r "${REALM_NAME}" \
                -s email="${email}" \
                -s firstName="${firstname}" \
                -s lastName="${lastname}" \
                -s "attributes.jobTitle=[\"${jobtitle}\"]" 2>/dev/null || true
            
            echo "  Successfully updated user: $username"
            echo "${username}:${user_password}" >> "$PLAINTEXT_FILE"
            updated_count=$((updated_count + 1))
            
        else
            echo "  Creating new user: $username"
            
            # Create a temporary JSON file for the user
            temp_user_file="/tmp/user_${username}.json"
            cat > "$temp_user_file" <<EOF
{
    "username": "${username}",
    "email": "${email}",
    "firstName": "${firstname}",
    "lastName": "${lastname}",
    "enabled": true,
    "emailVerified": true,
    "attributes": {
        "jobTitle": ["${jobtitle}"]
    },
    "credentials": [{
        "type": "password",
        "value": "${user_password}",
        "temporary": false
    }]
}
EOF
            
            # Create the user with JSON file
            if /opt/keycloak/bin/kcadm.sh create users -r "${REALM_NAME}" -f "$temp_user_file" 2>/dev/null; then
                echo "  Successfully created user: $username"
                echo "${username}:${user_password}" >> "$PLAINTEXT_FILE"
                created_count=$((created_count + 1))
            else
                echo "  Failed to create user: $username"
                # Still save password in case we can use it later
                echo "${username}:${user_password}" >> "$PLAINTEXT_FILE"
                failed_count=$((failed_count + 1))
            fi
            
            # Clean up temp file
            rm -f "$temp_user_file"
        fi
        
        # Brief pause to avoid overwhelming Keycloak
        sleep 0.1
        
    done < /opt/keycloak/templates/passwd
    
    echo ""
    echo "User processing completed:"
    echo "- New users created: $created_count"
    echo "- Existing users updated: $updated_count"
    echo "- Failed operations: $failed_count"
    echo "- Total passwords in file: $(grep -c '^[^#].*:' "$PLAINTEXT_FILE" || echo 0)"
    echo "- Password file location: $PLAINTEXT_FILE"
    
else
    echo "Warning: /opt/keycloak/templates/passwd not found"
    echo "# No passwd template file found" >> "$PLAINTEXT_FILE"
fi

# Set proper permissions on password file
chmod 600 "$PLAINTEXT_FILE"

echo ""
echo "User processing completed successfully!"
echo "Password file: $PLAINTEXT_FILE"

# List users in realm for verification
echo ""
echo "Verifying users in realm ${REALM_NAME}:"
total_users=$(/opt/keycloak/bin/kcadm.sh get users -r "${REALM_NAME}" --fields username 2>/dev/null | grep '"username"' | wc -l || echo 0)
echo "Total users in realm: $total_users"

# Show sample of password file
echo ""
echo "Sample from password file:"
head -n 8 "$PLAINTEXT_FILE" | tail -n 5
