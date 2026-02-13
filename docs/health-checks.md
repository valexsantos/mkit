# Health Checks

MKIt supports Kubernetes-style liveness and readiness probes for automatic container health monitoring.

## Overview

- **Liveness Probe**: Determines if a container needs to be restarted
- **Readiness Probe**: Determines if a container should receive traffic

## Configuration

Add probes to your service.yaml:

```yaml
service:
  name: my-app
  image: nginx:latest
  liveness_probe:
    type: http
    path: /healthz
    port: 8080
    initial_delay_seconds: 30
    period_seconds: 10
    timeout_seconds: 3
    failure_threshold: 3
    success_threshold: 1
  readiness_probe:
    type: http
    path: /ready
    port: 8080
    initial_delay_seconds: 5
    failure_threshold: 3
    success_threshold: 2
```

## Probe Types

### HTTP Probe

```yaml
liveness_probe:
  type: http
  path: /healthz      # URL path (default: /)
  port: 8080         # port (default: 80)
```

Success: HTTP status code 2xx or 3xx

### TCP Probe

```yaml
readiness_probe:
  type: tcp
  port: 5432         # port to check
```

Success: TCP connection accepted

### Exec Probe

```yaml
liveness_probe:
  type: exec
  command: ["cat", "/tmp/healthy"]
```

Success: Exit code 0

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `type` | Probe type: `http`, `tcp`, `exec` | Required |
| `path` | URL path for HTTP probe | `/` |
| `port` | Port for HTTP/TCP probe | `80` |
| `command` | Command for exec probe | - |
| `initial_delay_seconds` | Seconds to wait before first probe | `0` |
| `period_seconds` | How often to run probe | `10` |
| `timeout_seconds` | Probe timeout | `5` |
| `failure_threshold` | Consecutive failures before action | `3` |
| `success_threshold` | Consecutive successes before ready | `1` |

## Behavior

### Liveness Probe

1. After `initial_delay_seconds`, probe runs every `period_seconds`
2. On failure: increments failure counter
3. When failures >= `failure_threshold`: container is restarted
4. On success: failure counter resets

### Readiness Probe

1. After `initial_delay_seconds`, probe runs every `period_seconds`
2. On failure: increments failure counter, marks pod as `DEGRADED`
3. When failures >= `failure_threshold`: pod stays degraded
4. On success: increments success counter
5. When successes >= `success_threshold`: pod marked as `RUNNING`

## Monitoring

View pod health status:

```bash
mkit get my-app -d
```

Pod metrics include:
- `consecutive_liveness_failures`
- `consecutive_readiness_failures`
- `last_health_check_at`
