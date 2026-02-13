# Metrics

MKIt provides a Prometheus-compatible metrics endpoint for monitoring.

## Endpoint

```
GET /metrics
```

## Available Metrics

### Service Metrics

```
mkit_service_replicas{name="my-service"} 3
mkit_service_replicas_running{name="my-service"} 2
mkit_service_version{name="my-service"} 1
mkit_services_total 5
```

### Pod Metrics

```
mkit_pod_info{name="abc123",service="my-service"} 1
mkit_pod_status{name="abc123",status="running"} 1
mkit_pod_cpu_percent{name="abc123"} 45.2
mkit_pod_memory_percent{name="abc123"} 62.1
mkit_pods_total 12
```

### System Metrics

```
mkit_cpu_count 4
mkit_memory_total_bytes 8589934592
mkit_services_count 5
mkit_pods_count 12
```

## Usage

```bash
# Fetch metrics
curl https://localhost:4567/metrics

# Scrape with Prometheus
# Add to prometheus.yml:
scrape_configs:
  - job_name: 'mkit'
    static_configs:
      - targets: ['localhost:4567']
```

## Integration

Metrics are updated in real-time by the autoscaler and health check workers.
