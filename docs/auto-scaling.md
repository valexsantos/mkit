# Auto-scaling

MKIt supports horizontal pod autoscaling (HPA-like) based on CPU and memory utilization.

## Overview

The autoscaler automatically adjusts the number of pod replicas based on resource usage:
- **Scale up** when CPU or memory exceeds threshold
- **Scale down** when CPU and memory fall below 50% of threshold

## Configuration

Add scaling config to your service.yaml:

```yaml
service:
  name: my-app
  image: nginx:latest
  resources:
    min_replicas: 1
    max_replicas: 10
    limits:
      cpu: 500m
      memory: 256Mi
    scaling:
      target_cpu_percent: 70
      target_memory_percent: 80
      scale_up_stabilization_seconds: 60
      scale_down_stabilization_seconds: 300
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `min_replicas` | Minimum number of pods | `1` |
| `max_replicas` | Maximum number of pods | `min_replicas` |
| `target_cpu_percent` | Scale up when CPU > this % | - (disabled) |
| `target_memory_percent` | Scale up when Memory > this % | - (disabled) |
| `scale_up_stabilization_seconds` | Wait between scale-up events | `0` |
| `scale_down_stabilization_seconds` | Wait between scale-down events | `0` |

## How It Works

1. Autoscaler runs every 30 seconds
2. Collects CPU/memory metrics from Docker stats
3. Calculates average utilization across all pods
4. **Scale up**: If avg CPU > target OR avg Memory > target
5. **Scale down**: If avg CPU < 50% of target AND avg Memory < 50% of target
6. Respects stabilization windows to prevent flapping

## Manual Scaling

You can also manually scale a service:

```bash
# Scale to 5 replicas
mkit scale my-app 5
```

## CLI Commands

```bash
# Scale service
mkit scale <service> <replicas>

# View current replicas
mkit get my-app -d
```

## Metrics

View scaling metrics at:

```bash
curl https://localhost:4567/metrics
```

Relevant metrics:
```
mkit_service_replicas{name="my-app"} 5
mkit_service_replicas_running{name="my-app"} 4
mkit_pod_cpu_percent{name="pod-1"} 45.2
mkit_pod_memory_percent{name="pod-1"} 62.1
```
