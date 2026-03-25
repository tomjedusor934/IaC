# CI/CD Workflows

## Overview

All workflows use GitHub Actions with **Workload Identity Federation** for keyless authentication to GCP. Runners can be either GitHub-hosted (`ubuntu-latest`) or self-hosted via ARC (configured via the `RUNNER_LABEL` repository variable).

## Workflow Matrix

| Workflow | Trigger | Runner | Purpose |
|----------|---------|--------|---------|
| `terraform-ci.yml` | PR on `terraform/**` | Dynamic | `fmt`, `validate`, `plan` for both envs |
| `terraform-apply-dev.yml` | Push to `develop` on `terraform/**` | Dynamic | Apply Terraform to dev |
| `terraform-apply-prd.yml` | Push to `main` on `terraform/**` | Dynamic | Apply Terraform to prd |
| `app-ci.yml` | PR on `app/**`, `helm/**` | Dynamic | Lint (ruff), test (pytest), Docker build |
| `app-deploy-dev.yml` | Push to `develop` on `app/**`, `helm/**` | Dynamic | Build → Push → Helm upgrade (dev) |
| `app-deploy-prd.yml` | Tag push `v*` | Dynamic | Build → Push → Helm upgrade (prd) |
| `destroy.yml` | Manual (workflow_dispatch) | Dynamic | Destroy infrastructure (with confirmation) |

## Dynamic Runner Selection

All workflows use:
```yaml
runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
```

- **Before ARC is deployed**: Leave `RUNNER_LABEL` unset → runs on GitHub-hosted runners
- **After ARC is deployed**: Set `RUNNER_LABEL` to your ARC runner label (e.g., `arc-runner-set`) → runs on self-hosted runners in GKE

## Authentication Flow

```
GitHub Actions Runner
    │
    ├── Requests OIDC token from GitHub
    │
    ├── google-github-actions/auth@v2
    │     └── Exchanges OIDC token for short-lived GCP credentials
    │           via Workload Identity Federation
    │
    ├── google-github-actions/setup-gcloud@v2
    │     └── Configures gcloud CLI with WIF credentials
    │
    ├── google-github-actions/get-gke-credentials@v2
    │     └── Fetches kubeconfig for GKE cluster
    │
    └── Executes: terraform apply / helm upgrade / docker push
```

## Terraform Workflows

### terraform-ci (PR validation)

1. **Format Check** — `terraform fmt -check -recursive`
2. **Validate Dev** — `terraform init` + `terraform validate` on `environments/dev/`
3. **Validate Prd** — `terraform init` + `terraform validate` on `environments/prd/`
4. **Plan Dev** — `terraform plan` on `environments/dev/` (output in PR comment)
5. **Plan Prd** — `terraform plan` on `environments/prd/` (output in PR comment)

### terraform-apply-dev / terraform-apply-prd

1. Authenticate via WIF
2. `terraform init`
3. `terraform apply -auto-approve`

## Application Workflows

### app-ci (PR validation)

1. **Lint** — `ruff check app/` + `ruff format --check app/`
2. **Test** — `pytest app/tests/ -v --cov=app`
3. **Docker Build** — Build image (no push, validates Dockerfile)

### app-deploy-dev / app-deploy-prd

1. Authenticate via WIF
2. Configure Docker for Artifact Registry
3. Build and push Docker image (tag: `$SHA`)
4. Get GKE credentials
5. `helm upgrade --install` with environment-specific values

## Destroy Workflow

Manual workflow with safety confirmation:
1. Triggered via `workflow_dispatch` with `confirm_destroy` input
2. Must type the exact environment name to confirm
3. Runs `terraform destroy -auto-approve` on the specified environment

## Required GitHub Configuration

### Repository Variables

| Variable | Description |
|----------|-------------|
| `RUNNER_LABEL` | (Optional) ARC runner label, leave unset for GitHub-hosted |

### Environment Secrets / Variables

Set these in GitHub → Settings → Environments → `dev` / `prd`:

| Name | Type | Description |
|------|------|-------------|
| `GCP_PROJECT_ID` | Variable | GCP project ID |
| `GCP_WIF_PROVIDER` | Variable | Full WIF provider path |
| `GCP_SA_EMAIL` | Variable | WIF service account email |
| `GKE_CLUSTER_NAME` | Variable | GKE cluster name |
| `GKE_CLUSTER_ZONE` | Variable | GKE cluster zone/region |
