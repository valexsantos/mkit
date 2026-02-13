# Service Configuration

## Overview

A service is defined in a YAML file that describes how to deploy and configure your containerized application.

## Basic Structure

```yaml
service:
  name: my-service        # unique name, available as DNS: my-service.internal
  image: nginx:latest    # docker image
  network: bridge        # docker network
  command: []            # override container command
  resources: {}          # resource limits and scaling
  volumes: []            # volume mounts
  environment: {}        # environment variables
  ingress: {}            # HAProxy ingress configuration
  liveness_probe: {}     # liveness probe
  readiness_probe: {}    # readiness probe
```

## Complete Example

```yaml
service:
  name: rabbitmq
  image: rabbitmq:3-management-alpine
  network: bridge
  ingress:
    frontend:
      - name: http-in-ssl
        options:
          - option httpclose
          - option forwardfor
        bind:
          port: 443
          ssl: true
          mode: http
          cert: /etc/ssl/certs/server.crt
          options:
            - accept-proxy
            - transparent
            - defer-accept
        default_backend: admin
      - name: http-in
        bind:
          port: 80
          mode: http
        default_backend: admin
      - name: server-in
        bind:
          port: 5672
          mode: tcp
        default_backend: server
    backend:
      - name: admin
        balance: round_robin
        options:
          - option httpclose
          - option forwardfor
          - cookie JSESSIONID prefix
        bind:
          port: 15672
          mode: http
          options:
            - cookie A
            - check
      - name: server
        balance: round_robin
        bind:
          port: 5672
          mode: tcp
  resources:
    min_replicas: 1
    max_replicas: 1
    limits:
      cpu: 250m
      memory: 250m
      memory_swap: 250m
  volumes:
    - docker://mkit_rabbitmq_data:/var/lib/rabbitmq
    - /var/log/rabbitmq/logs:/var/log/rabbitmq
  environment:
    RABBITMQ_DEFAULT_USER: admin
    RABBITMQ_DEFAULT_PASS: admin
    RABBITMQ_DEFAULT_VHOST: mkit
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Unique service name (DNS: name.internal) |
| `image` | string | Docker image |
| `network` | string | Docker network (created if doesn't exist) |
| `command` | array | Override container command |
| `resources` | object | Resource limits and scaling config |
| `volumes` | array | Volume mounts |
| `environment` | object | Environment variables |
| `ingress` | object | HAProxy configuration |
| `liveness_probe` | object | Liveness probe config |
| `readiness_probe` | object | Readiness probe config |

## Resources

```yaml
resources:
  min_replicas: 1        # minimum pods (default: 1)
  max_replicas: 10       # maximum pods
  limits:
    cpu: 250m            # CPU limit (1000m = 1 core)
    memory: 250m        # Memory limit
    memory_swap: 250m   # Memory + swap limit
  scaling:
    target_cpu_percent: 70      # scale up when CPU > 70%
    target_memory_percent: 80    # scale up when Memory > 80%
    scale_up_stabilization_seconds: 60
    scale_down_stabilization_seconds: 300
```

## Volumes

```yaml
volumes:
  - docker://volume_name:/container/path  # Docker volume
  - /host/path:/container/path            # Bind mount
```

## Environment

```yaml
environment:
  # Plain text
  DEBUG: "true"
  
  # Vault reference (see Vault documentation)
  DB_PASSWORD: "vault:/services/my-app/database#PASSWORD"
```

## Ingress

See [HAProxy configuration](https://docs.haproxy.org/3.1/configuration.html) for frontend and backend options.

## Probes

See [Health Checks](health-checks.md) documentation for probe configuration.
