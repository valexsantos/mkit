# Backup & Restore

MKIt supports backing up and restoring cluster state.

## Overview

Backups include:
- Service configurations
- Pod states
- Vault secrets (metadata only, values encrypted)
- MKIt configuration

## CLI Commands

```bash
# Create backup
mkit backup create my-backup
mkit backup create  # auto-generated name

# List backups
mkit backup list

# Restore from backup
mkit backup restore /var/lib/mkitd/backups/my-backup.tar.gz
```

## API Endpoints

```bash
# Create backup
POST /mkit/backup
{"name": "pre-upgrade"}

# List backups
GET /mkit/backups

# Restore
POST /mkit/restore
{"backup_path": "/var/lib/mkitd/backups/my-backup.tar.gz"}
```

## Backup Location

Default: `/var/lib/mkitd/backups/`

## Limitations

- Only database state is backed up
- Docker containers are NOT included (they'll be recreated on restore)
- Vault secret values are encrypted in backups
- Pod IPs may change after restore
