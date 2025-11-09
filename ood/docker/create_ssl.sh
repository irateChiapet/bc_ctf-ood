# Create SSL directory
mkdir -p /opt/ood/ssl
cd /opt/ood

# Generate self-signed certificates for both services
openssl req -x509 -newkey rsa:4096 -keyout ./ssl/ood.key -out ./ssl/ood.crt -days 365 -nodes -subj "/CN=${HOSTNAME:-localhost}/O=OnDemand/C=US"

openssl req -x509 -newkey rsa:4096 -keyout ./ssl/keycloak.key -out ./ssl/keycloak.crt -days 365 -nodes -subj "/CN=${HOSTNAME:-localhost}/O=Keycloak/C=US"

# Set proper permissions
chmod 600 ./ssl/*.key
chmod 644 ./ssl/*.crt
