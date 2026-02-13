# MKIt Documentation

## Getting Started

- [Installation](README.md) - Basic setup and installation
- [Service Configuration](service-configuration.md) - Complete service YAML reference

## Features

### Core Features
- [Vault Service](vault.md) - Centralized secrets management
- [Health Checks](health-checks.md) - Liveness and readiness probes
- [Auto-scaling](auto-scaling.md) - HPA-like horizontal pod autoscaling
- [Metrics](metrics.md) - Prometheus-compatible metrics endpoint
- [Backup & Restore](backup-restore.md) - Cluster state backup and recovery
- [Dry-run Mode](dry-run.md) - Preview configurations without applying

## CLI Commands

### Service Management
```bash
mkit create <file>           # Create service
mkit update <file>          # Update service
mkit create <file> --dry-run # Preview without creating
mkit update <file> --dry-run # Preview without applying
mkit start <service>        # Start service
mkit stop <service>          # Stop service
mkit restart <service>       # Restart service
mkit scale <service> <n>    # Scale to N replicas
mkit rm <service>            # Remove service
```

### Service Information
```bash
mkit ps                      # List all services
mkit status                  # Show status
mkit status <service>        # Show service status
mkit status <service> -e     # Show status with errors
mkit get <service>           # Get service configuration
mkit get <service> -d        # Get with details
mkit logs <service>          # View logs
mkit exec <service> -- <cmd> # Execute command
```

### Vault
```bash
mkit vault list              # List all secrets
mkit vault list services     # List by scope
mkit vault get <path>        # Get secret metadata
mkit vault set <path>#<key> <value>  # Set secret
mkit vault delete <path>#<key>       # Delete secret
```

### Backup
```bash
mkit backup create <name>    # Create backup
mkit backup list             # List backups
mkit backup restore <path>   # Restore backup
```

### Other
```bash
mkit proxy start|stop|restart|status  # HAProxy control
mkit profile set <name>     # Switch profile
mkit version                # Show version
```
