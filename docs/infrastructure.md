# Infrastructure Documentation

## Overview

This project deploys a cloud-native task management API on Google Cloud Platform using Infrastructure as Code (Terraform), Kubernetes (GKE), and Helm charts.

## Architecture Components

### VPC Network (`terraform/modules/vpc`)

| Resource | Description |
|----------|-------------|
| VPC | `gke-vpc` — custom-mode, no default routes for internet |
| Subnet | `gke-subnet` — `10.0.0.0/20` with secondary ranges for pods (`10.16.0.0/14`) and services (`10.20.0.0/20`) |
| Cloud Router | Provides dynamic routing for Cloud NAT |
| Cloud NAT | Enables outbound internet for private GKE nodes |
| Private Service Access | Peering for Cloud SQL private IP |
| Firewall | Webhook rule allowing GKE master CIDR to target ARC runner pods on port 9443 |

### GKE Cluster (`terraform/modules/gke`)

- **Type**: Standard (not Autopilot), private cluster
- **Networking**: Dataplane V2 (eBPF-based, enables NetworkPolicy)
- **Node Pools**:

| Pool | Machine | Min | Max | Purpose |
|------|---------|-----|-----|---------|
| default | e2-standard-2 | 1 | 3 | System workloads |
| app | e2-standard-2 (dev) / e2-standard-4 (prd) | 1 | 5 | Application pods |
| runner | e2-standard-4 | 0 | 5 | ARC self-hosted runners (taint: `workload=runner:NoSchedule`) |

- **Features**: Workload Identity, Vertical Pod Autoscaling, HTTP Load Balancing, GCE Persistent Disk CSI

### Cloud SQL (`terraform/modules/cloudsql`)

- **Engine**: PostgreSQL 15
- **Connectivity**: Private IP only (via PSA peering)
- **Tier**: `db-f1-micro` (dev) / `db-custom-2-8192` (prd)
- **High Availability**: Disabled (dev) / Regional (prd)
- **Backups**: Enabled, point-in-time recovery enabled
- **Password**: Auto-generated via `random_password`, stored in Secret Manager

### Workload Identity Federation (`terraform/modules/wif`)

Enables GitHub Actions to authenticate to GCP without long-lived credentials:

1. **WIF Pool** → identity boundary
2. **OIDC Provider** → validates GitHub OIDC tokens (`token.actions.githubusercontent.com`)
3. **Attribute Condition** → restricts to `HERE_GITHUB_OWNER/HERE_GITHUB_REPO_NAME`
4. **Service Account** → with roles: `roles/container.developer`, `roles/artifactregistry.writer`, `roles/iam.serviceAccountTokenCreator`
5. **IAM Binding** → principalSet matching the GitHub repository

### IAM (`terraform/modules/iam`)

- App Service Account with `roles/cloudsql.client` and `roles/secretmanager.secretAccessor`
- Workload Identity binding: `serviceAccount:PROJECT_ID.svc.id.goog[app/fastapi-app]`

### Artifact Registry (`terraform/modules/artifact-registry`)

- Docker format registry in `europe-west1`
- Cleanup policy: keep only 10 most recent versions per image

## Environments

| Property | Dev | Prd |
|----------|-----|-----|
| Region | europe-west1 | europe-west1 |
| App node machine | e2-standard-2 | e2-standard-4 |
| Cloud SQL tier | db-f1-micro | db-custom-2-8192 |
| Cloud SQL HA | ZONAL | REGIONAL |
| Deletion protection | false | true |
| Ingress replicas | 1 | 2 |
| Prometheus replicas | 1 | 2 |
| Monitoring retention | 7d | 30d |

## Namespaces

| Namespace | Purpose |
|-----------|---------|
| `app` | FastAPI application pods |
| `runners` | ARC controller and runner pods |
| `monitoring` | Prometheus, Grafana, Alertmanager |
| `ingress-nginx` | NGINX Ingress Controller |
| `cert-manager` | TLS certificate automation |
| `external-secrets` | External Secrets Operator |

## Helm Releases (deployed by Terraform)

| Chart | Version | Namespace |
|-------|---------|-----------|
| ingress-nginx | 4.11.3 | ingress-nginx |
| cert-manager | v1.16.1 | cert-manager |
| actions-runner-controller | 0.9.3 | runners |
| kube-prometheus-stack | 62.7.0 | monitoring |
| external-secrets | 0.10.5 | external-secrets |
| fastapi-app (custom) | 0.1.0 | app |
