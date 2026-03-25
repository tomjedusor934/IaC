# Monitoring & Observability

## Stack

| Component | Chart | Version | Purpose |
|-----------|-------|---------|---------|
| Prometheus | kube-prometheus-stack | 62.7.0 | Metrics collection |
| Grafana | (bundled) | — | Dashboards & visualization |
| Alertmanager | (bundled) | — | Alert routing |
| ServiceMonitor | (custom) | — | Scrapes FastAPI `/metrics` |

## Metrics Exposed by FastAPI

The application uses `prometheus-fastapi-instrumentator` to automatically expose:

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total requests by method, status, handler |
| `http_request_duration_seconds` | Histogram | Request duration with P50/P95/P99 buckets |
| `http_requests_inprogress` | Gauge | Currently in-flight requests |

Endpoint: `GET /metrics` (Prometheus format)

## ServiceMonitor

Defined in `helm/fastapi-app/templates/servicemonitor.yaml`:
- Scrapes the `http` port of the FastAPI service
- Interval: `15s`
- Path: `/metrics`
- Namespace selector: `app`

## Alert Rules

Defined in `monitoring/alerts/fastapi-app-alerts.yaml` (PrometheusRule CRD):

### Application Alerts

| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| FastAPIHighErrorRate | 5xx rate > 5% | critical | 5m |
| FastAPIHighLatencyP95 | P95 > 1s | warning | 10m |
| FastAPIHighLatencyP99 | P99 > 2s | critical | 5m |
| FastAPIHighRequestRate | Rate > 100 req/s | warning | 5m |

### Scaling Alerts

| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| PodCrashLooping | Restarts > 3 in 15m | critical | 5m |
| HPAMaxedOut | current == max replicas | warning | 15m |
| PodNotReady | Pod not ready | warning | 10m |

### Runner Alerts

| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| RunnerPoolMaxed | Runner pods == max (5) | warning | 10m |
| RunnerPodFailing | Runner restarts > 2 in 10m | warning | 5m |

### Infrastructure Alerts

| Alert | Condition | Severity | For |
|-------|-----------|----------|-----|
| HighNodeCPU | Node CPU > 85% | warning | 10m |
| HighNodeMemory | Node memory > 85% | warning | 10m |
| PersistentVolumeAlmostFull | PV > 85% full | warning | 5m |

## Grafana Dashboard

Pre-built dashboard: `monitoring/dashboards/fastapi-app-dashboard.json`

Panels:
1. **Request Rate** — req/s by HTTP method
2. **Error Rate** — 5xx errors/s
3. **Response Latency** — P50, P95, P99
4. **HTTP Status Codes** — Pie chart distribution
5. **Active Replicas** — Current pod count
6. **Pod CPU Usage** — Per-pod CPU consumption
7. **Pod Memory Usage** — Per-pod memory consumption
8. **Requests In Progress** — Current in-flight count

### Importing the Dashboard

```bash
# Via Grafana UI:
# 1. Navigate to Dashboards → Import
# 2. Upload monitoring/dashboards/fastapi-app-dashboard.json
# 3. Select the Prometheus data source

# Via kubectl ConfigMap (auto-imported by kube-prometheus-stack):
kubectl create configmap grafana-fastapi-dashboard \
  --from-file=fastapi-app-dashboard.json=monitoring/dashboards/fastapi-app-dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | \
  kubectl label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl apply -f -
```

## Accessing Grafana

```bash
# Port-forward to local machine
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Open http://localhost:3000
# Default credentials: admin / admin (dev) | admin / HERE_GRAFANA_ADMIN_PASSWORD (prd)
```

## Environment Differences

| Setting | Dev | Prd |
|---------|-----|-----|
| Retention | 7 days | 30 days |
| Storage | 10Gi | 50Gi |
| Prometheus replicas | 1 | 2 |
| Grafana admin password | admin | `HERE_GRAFANA_ADMIN_PASSWORD` |
