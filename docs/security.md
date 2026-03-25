# Security

## Identity & Authentication

### Workload Identity Federation (WIF)

**Zero long-lived credentials** — GitHub Actions authenticates to GCP using OIDC tokens:

```
GitHub Runner → OIDC Token → GCP WIF Pool → OIDC Provider → GCP SA → Short-lived Access Token
```

- **Attribute Condition**: restricts token exchange to a specific GitHub repository
- **Token Lifetime**: Short-lived (1 hour max), automatically rotated per workflow run
- **No Service Account Keys**: No JSON keys stored in GitHub Secrets

### GKE Workload Identity

Application pods use Kubernetes Service Accounts mapped to GCP Service Accounts:

```
K8s SA (app/fastapi-app) → GCP SA (fastapi-app-sa) → Cloud SQL + Secret Manager
```

- Pods cannot impersonate other GCP identities
- Each namespace has isolated permissions

### JWT Authentication

The FastAPI API uses JWT Bearer tokens:
- Algorithm: HS256
- Secret: Configured via `JWT_SECRET_KEY` environment variable
- Expiry: 30 minutes
- Endpoint: `POST /api/v1/auth/token`

## Network Security

### Private GKE Cluster

- **Private nodes**: No public IP addresses on worker nodes
- **Private endpoint**: Control plane accessible only from authorized networks
- **Authorized networks**: Configurable master CIDR range
- **Cloud NAT**: Outbound-only internet access for nodes

### VPC Network

- Custom-mode VPC (no auto-created subnets)
- Dedicated subnet for GKE with non-overlapping secondary ranges
- Private Service Access for Cloud SQL (no public IP)
- Firewall rules restricted to necessary ports only

### Dataplane V2 (Cilium/eBPF)

- Built-in NetworkPolicy enforcement without additional CNI plugins
- Improved observability and performance
- Kernel-level packet filtering

## Data Security

### Cloud SQL

- **Private IP only** — no public endpoint
- **Encrypted in transit** — Cloud SQL Auth Proxy with mTLS
- **Encrypted at rest** — Google-managed encryption keys
- **Automated backups** — with point-in-time recovery
- **Password management** — auto-generated, stored in Secret Manager

### Secret Manager

- Database password stored as a Secret Manager secret
- Accessed via GKE Workload Identity (no hardcoded credentials)
- External Secrets Operator can sync secrets to Kubernetes

## Container Security

### Multi-Stage Docker Build

- Builder stage separated from runtime
- Minimal final image: `python:3.12-slim`
- Non-root user (`appuser`, UID 1001)
- Read-only principles applied

### Pod Security

- `runAsNonRoot: true`
- `runAsUser: 1001`
- Resource limits enforced (CPU + memory)
- Health checks (liveness + readiness probes)
- Pod Disruption Budget (PDB) ensures availability

## CI/CD Security

### Pipeline Protections

- **Branch protection**: `main` and `develop` require PRs
- **CI validation**: lint + test + plan must pass before merge
- **Environment approvals**: Production deploys can require manual approval
- **Destroy safeguard**: Manual trigger with typed confirmation

### Supply Chain

- Pinned Helm chart versions (no `latest`)
- Pinned GitHub Action versions (SHA-based recommended)
- Artifact Registry with cleanup policies (keep 10 versions)
- Docker image tagged with commit SHA (immutable)

## Rate Limiting

- FastAPI rate limiting via `slowapi`: 100 requests/minute per IP
- Configurable via environment variables

## CORS

- Configurable allowed origins
- Defaults to restricted in production

## Checklist

- [x] No long-lived cloud credentials
- [x] Private GKE cluster with Cloud NAT
- [x] Database on private IP only
- [x] Passwords auto-generated and stored in Secret Manager
- [x] Non-root containers
- [x] Pod resource limits
- [x] Network policies via Dataplane V2
- [x] JWT authentication on API
- [x] Rate limiting
- [x] CI validation before deploy
- [x] Immutable image tags (SHA-based)
