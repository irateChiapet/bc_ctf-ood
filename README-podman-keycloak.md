# OpenOnDemand with Keycloak Authentication - Podman Deployment

This deployment uses podman-compose to run OpenOnDemand with Keycloak as the OIDC authentication provider. All configuration is managed through environment variables for easy customization.

## Prerequisites

- Podman and podman-compose installed
- Ports defined in `.env` file available on the host system (default: 80 and 8080)

## Architecture

```
┌─────────────┐    ┌─────────────┐
│             │    │             │
│ OpenOnDemand│◄──►│  Keycloak   │
│  (Port 80)  │    │ (Port 8080) │
│             │    │             │
└─────────────┘    └─────────────┘
```

## Configuration

The deployment is configured through a `.env` file. Copy and modify the provided `.env` file:

```bash
# Environment configuration for OpenOnDemand with Keycloak
HOSTNAME=ood.hpc.local
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin123
KEYCLOAK_HTTP_PORT=8080
OOD_HTTP_PORT=80
OOD_HTTPS_PORT=443
OIDC_CLIENT_SECRET=ondemand-secret-123
OIDC_CRYPTO_PASSPHRASE=openondemand-crypto-passphrase-change-me
```

**Important:** Change the `HOSTNAME` variable to match your deployment hostname.

## Quick Start

1. **Navigate to the deployment directory:**
   ```bash
   cd /opt/ood
   ```

2. **Configure your hostname:**
   ```bash
   # Edit the .env file to set your hostname
   vi .env
   # Change HOSTNAME=ood.hpc.local to HOSTNAME=your.domain.com
   ```

3. **Build and start the services:**
   ```bash
   podman-compose up --build -d
   ```

4. **Wait for services to be healthy:**
   ```bash
   podman-compose ps
   ```
   Wait until both services show "healthy" status.

5. **Access OpenOnDemand:**
   - Open your browser to `http://YOUR_HOSTNAME` (as defined in .env)
   - You'll be redirected to Keycloak for authentication

6. **Login with test accounts:**
   - Username: `testuser1`, Password: `password123`
   - Username: `testuser2`, Password: `password123`  
   - Username: `admin`, Password: `admin123`

## Test User Accounts

The Keycloak realm comes pre-configured with three test users:

| Username  | Password    | Email               | Role |
|-----------|-------------|---------------------|------|
| testuser1 | password123 | testuser1@example.com | User |
| testuser2 | password123 | testuser2@example.com | User |
| admin     | admin123    | admin@example.com     | User |

## Services Configuration

### Keycloak Configuration

- **Realm:** `ondemand`
- **Client ID:** `ondemand`
- **Client Secret:** Defined by `OIDC_CLIENT_SECRET` in `.env`
- **Port:** Defined by `KEYCLOAK_HTTP_PORT` in `.env`
- **Admin Console:** `http://YOUR_HOSTNAME:KEYCLOAK_HTTP_PORT/admin`
  - Admin Username: Defined by `KEYCLOAK_ADMIN` in `.env`
  - Admin Password: Defined by `KEYCLOAK_ADMIN_PASSWORD` in `.env`

### OpenOnDemand Configuration

- **Port:** Defined by `OOD_HTTP_PORT` in `.env` (default: 80)
- **OIDC Provider:** Keycloak instance
- **Authentication:** OIDC via mod_auth_openidc  
- **Configuration:** Generated from `/opt/ood/config/ood_portal.yml.template`

## Directory Structure

```
/opt/ood/
├── .env                           # Environment configuration
├── podman-compose.yml             # Main compose file
├── Dockerfile.ood                 # OpenOnDemand container
├── docker/
│   ├── start-ondemand.sh         # Container startup script
│   └── init-keycloak.sh          # Keycloak initialization script
├── config/
│   ├── ood_portal.yml.template   # OOD portal configuration template
│   └── clusters.d/
│       └── ood.hpc.local.yml         # Local cluster config
├── keycloak/
│   └── realm-import.json.template # Keycloak realm configuration template
└── README-podman-keycloak.md     # This documentation
```

## Useful Commands

### Container Management

```bash
# Navigate to deployment directory
cd /opt/ood

# Start services
podman-compose up -d

# Stop services  
podman-compose down

# View logs
podman-compose logs ondemand
podman-compose logs keycloak

# Restart a service
podman-compose restart ondemand

# Build and restart (after config changes)
podman-compose up --build -d
```

### Debugging

```bash
# Check container status
podman-compose ps

# Access container shell
podman exec -it ood-app bash
podman exec -it ood-keycloak bash

# View OOD logs
podman exec -it ood-app tail -f /var/log/httpd/error_log
podman exec -it ood-app tail -f /var/log/httpd/access_log

# Check OOD portal config generation
podman exec -it ood-app cat /etc/httpd/conf.d/ood-portal.conf
```

### Environment Variable Changes

After modifying the `.env` file:

```bash
cd /opt/ood

# Restart services to pick up new environment variables
podman-compose down
podman-compose up -d

# For template changes, rebuild containers
podman-compose up --build -d
```

### Configuration Template Changes

After modifying configuration templates in `/opt/ood/config/` or `/opt/ood/keycloak/`:

```bash
cd /opt/ood

# Rebuild and restart to process new templates
podman-compose down
podman-compose up --build -d
```

## Troubleshooting

### Common Issues

1. **Services not starting:**
   ```bash
   # Check if ports are available
   ss -tulpn | grep -E ':(80|8080)'
   
   # View detailed logs
   podman-compose logs
   ```

2. **Authentication not working:**
   ```bash
   # Verify Keycloak is accessible (replace with your hostname and port from .env)
   curl -f http://YOUR_HOSTNAME:KEYCLOAK_HTTP_PORT/realms/ondemand/.well-known/openid-configuration
   
   # Check generated OIDC configuration
   podman exec -it ood-app cat /etc/ood/config/ood_portal.yml
   
   # Verify environment variables are set correctly
   podman exec -it ood-app env | grep -E "(HOSTNAME|KEYCLOAK|OIDC)"
   ```

3. **Permission issues:**
   ```bash
   # Check SELinux contexts (if applicable)
   ls -Z /opt/ood/config/
   
   # Fix permissions if needed
   sudo chcon -Rt container_file_t /opt/ood/config/
   ```

4. **Container build failures:**
   ```bash
   # Clean up and rebuild
   podman-compose down
   podman rmi ood-with-keycloak:latest
   podman-compose up --build -d
   ```

### Debug Mode

Enable debug logging by editing `/opt/ood/config/ood_portal.yml`:

```yaml
lua_log_level: 'debug'
```

Then restart:

```bash
cd /opt/ood
podman-compose restart ondemand
```

### Network Connectivity Issues

```bash
# Test container network connectivity
podman exec -it ood-app curl -f http://keycloak:8080/realms/ondemand/.well-known/openid-configuration

# Check network configuration
podman network ls
podman network inspect ood_ood-network
```

## Security Notes

⚠️ **This configuration is for development/testing only!**

For production use:

1. **Change all default passwords and secrets**
2. **Enable HTTPS with proper SSL certificates**
3. **Configure proper user mapping**
4. **Set up persistent volumes for data**
5. **Configure proper network security**
6. **Use external databases instead of H2**

## Customization

### Adding Users

1. Access Keycloak admin console: `http://ood.hpc.local:8080/admin`
2. Login with admin credentials (`admin` / `admin123`)
3. Navigate to Users → Add User
4. Set username, email, and other details
5. Go to Credentials tab and set password

### Configuring Additional Clusters

1. Create new YAML files in `/opt/ood/config/clusters.d/`
2. Follow OpenOnDemand cluster configuration documentation
3. Restart the ondemand service:
   ```bash
   cd /opt/ood
   podman-compose restart ondemand
   ```

### Modifying Authentication

Edit `/opt/ood/config/ood_portal.yml` to:
- Change OIDC scopes
- Modify user mapping rules  
- Configure additional OIDC settings
- Set up logout redirects

Example modifications:

```yaml
# Custom user mapping
user_map_match: '^([^@]+)@.*$'

# Additional OIDC scopes
oidc_scope: 'openid profile email groups'

# Custom logout redirect
logout_redirect: '/custom-logout-page'
```

## Production Deployment Considerations

For production deployment, consider:

1. **External Keycloak**: Use a dedicated Keycloak instance with proper HA
2. **SSL/TLS**: Configure HTTPS with proper certificates
3. **Database**: Use PostgreSQL/MySQL instead of H2 for Keycloak
4. **Load Balancing**: Set up load balancers for high availability  
5. **Monitoring**: Implement logging and monitoring solutions
6. **Backup**: Configure backup strategies for user data and configurations
7. **Resource Limits**: Set appropriate CPU/memory limits in compose file
8. **Health Checks**: Configure comprehensive health monitoring

## Environment Variables

All configuration is managed through the `.env` file. Available variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `HOSTNAME` | Deployment hostname | `ood.hpc.local` |
| `KEYCLOAK_ADMIN` | Keycloak admin username | `admin` |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | `admin123` |
| `KEYCLOAK_HTTP_PORT` | Keycloak HTTP port | `8080` |
| `OOD_HTTP_PORT` | OpenOnDemand HTTP port | `80` |
| `OOD_HTTPS_PORT` | OpenOnDemand HTTPS port | `443` |
| `OIDC_CLIENT_SECRET` | OIDC client secret | `ondemand-secret-123` |
| `OIDC_CRYPTO_PASSPHRASE` | OIDC encryption passphrase | `openondemand-crypto-passphrase-change-me` |

**Security Note:** Always change default passwords and secrets in production!

## Support and Resources

- **OpenOnDemand Documentation**: https://osc.github.io/ood-documentation/
- **Keycloak Documentation**: https://www.keycloak.org/documentation
- **This Deployment Issues**: Check logs and configuration files in `/opt/ood/`

## Cleaning Up

To completely remove the deployment:

```bash
cd /opt/ood

# Stop and remove containers
podman-compose down

# Remove volumes (WARNING: This deletes all data)
podman volume rm ood_keycloak_data ood_ood_data ood_ood_logs

# Remove network
podman network rm ood_ood-network

# Remove built image
podman rmi ood-with-keycloak:latest
```