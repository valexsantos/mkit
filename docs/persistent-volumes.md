# PersistentVolumes

MKIt supports Kubernetes-style PersistentVolumes (PV) for managing persistent storage independent of pod lifecycle.

## Overview

PersistentVolumes:
- Survive pod restarts and deletions
- Have explicit lifecycle (create, bind, release, delete)
- Support reclaim policies (Retain, Delete)

## CLI Commands

```bash
# List all volumes
mkit volume list

# Create a volume
mkit volume create my-data 10Gi
mkit volume create my-data 10Gi -r Delete

# Delete a volume
mkit volume delete my-data
```

## API Endpoints

```bash
# List volumes
GET /volumes

# Get volume
GET /volumes/:name

# Create volume
POST /volumes
{"name": "my-data", "capacity": "10Gi", "reclaim_policy": "Retain"}

# Delete volume
DELETE /volumes/:name
```

## Volume Lifecycle

1. **Available** - Volume created, ready to be claimed
2. **Bound** - Volume claimed by a service
3. **Released** - Claim deleted, volume available again
4. **Failed** - Volume encounterd an error

## Reclaim Policies

- **Retain** (default) - Data preserved after release
- **Delete** - Volume and data deleted on release

## Service Configuration

To use a persistent volume in a service:

```yaml
service:
  name: my-app
  image: postgres:14
  volumes:
    - persistent://my-data:/var/lib/postgresql/data
```

The `persistent://` prefix indicates a PersistentVolume claim.
