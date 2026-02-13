# Vault Service

MKIt includes a built-in Vault service for centralized secrets management.

## Overview

Vault provides secure storage for sensitive configuration data. Secrets are encrypted at rest and can be referenced in service configurations.

## Vault Paths

Vault uses a path-based scheme:

```
vault:/services/<service-name>/<resource>#KEY   # Service-specific secrets
vault:/mkit/<resource>#KEY                      # Cluster-wide secrets
```

### Examples

- `vault:/services/my-app/database#PASSWORD` - Service "my-app" database password
- `vault:/services/my-app/tls#CERT` - Service "my-app" TLS certificate  
- `vault:/mkit/haproxy#SSL_CERT` - Cluster HAProxy SSL certificate
- `vault:/mkit/registry#AUTH_TOKEN` - Docker registry auth token

## CLI Commands

```bash
# List all vault secrets
mkit vault list

# List secrets by scope
mkit vault list services
mkit vault list mkit

# Get secret metadata
mkit vault get services/my-app/database

# Set secret
mkit vault set services/my-app/database#PASSWORD mysecretpassword
mkit vault set mkit/registry#AUTH_TOKEN mytoken

# Delete secret
mkit vault delete services/my-app/database#PASSWORD
```

## Service Configuration

### Using Vault References

In your service.yaml, use `vault://` prefix for secrets:

```yaml
service:
  name: my-app
  image: nginx:latest
  environment:
    # Vault reference
    DB_PASSWORD: "vault:/services/my-app/database#PASSWORD"
    # Plain text (still works)
    DEBUG: "true"
    # Mixed
    API_TOKEN: "vault:/mkit/registry#AUTH_TOKEN"
```

### Validation

- **On service create/update**: Vault references are validated. Service won't be created if the vault path doesn't exist.
- **On service start/restart**: Vault references are re-validated. If a secret was deleted after the service was created, the service will fail to start with a clear error message.

### Viewing Errors

```bash
# Show service status with validation errors
mkit status my-app -e
```

Example output when vault secret is missing:
```
service:
  name: my-app
  status: error
  errors:
    - "Vault secret not found: vault:/services/my-app/database#PASSWORD"
```

## API Endpoints

```bash
# List all secrets
GET /vault

# List by scope
GET /vault/:scope

# Get secret metadata
GET /vault/:scope/:path

# Create secret
POST /vault
{"scope": "services", "path": "my-app/database", "key": "PASSWORD", "value": "secret123"}

# Update secret
PUT /vault/:scope/:path/:key
{"value": "newsecret"}

# Delete secret
DELETE /vault/:scope/:path/:key
```

## Security

- Secrets are encrypted with AES-256-CBC
- Encryption key can be set via `MKIT_VAULT_KEY` environment variable
- Default key used in development (change in production!)
- Secret values are never exposed in API responses or logs (only metadata)
