# Cloud-Native Architecture with Kubernetes, Helm & Identity Federation

A production-ready cloud-native task management API deployed on **GCP** using **Terraform**, **GKE**, **Helm**, **GitHub Actions**, and **Workload Identity Federation**.

## Repository Structure

```
├── .github/workflows/          # CI/CD pipelines
│   ├── terraform-ci.yml        # PR: validate + plan
│   ├── terraform-apply-dev.yml # Push develop: apply dev
│   ├── terraform-apply-prd.yml # Push main: apply prd
│   ├── app-ci.yml              # PR: lint + test + build
│   ├── app-deploy-dev.yml      # Push develop: deploy dev
│   ├── app-deploy-prd.yml      # Tag push: deploy prd
│   └── destroy.yml             # Manual: destroy infra
├── terraform/
│   ├── modules/                # Reusable Terraform modules
│   │   ├── vpc/                # VPC, subnet, NAT, PSA
│   │   ├── gke/                # GKE cluster + node pools
│   │   ├── cloudsql/           # PostgreSQL 15
│   │   ├── wif/                # Workload Identity Federation
│   │   ├── iam/                # App service account
│   │   └── artifact-registry/  # Docker registry
│   ├── environments/
│   │   ├── dev/                # Dev environment config
│   │   └── prd/                # Prd environment config
│   └── helm-releases/          # Monitoring Helm values
├── app/                        # FastAPI application
│   ├── models/                 # SQLAlchemy models
│   ├── schemas/                # Pydantic schemas
│   ├── services/               # Business logic
│   ├── routers/                # API endpoints
│   ├── auth/                   # JWT authentication
│   ├── middleware/              # Correlation ID
│   ├── tests/                  # Pytest test suite
│   ├── Dockerfile              # Multi-stage build
│   └── requirements.txt
├── helm/fastapi-app/           # Custom Helm chart
│   ├── templates/              # K8s manifests
│   ├── values.yaml             # Default values
│   ├── values-dev.yaml         # Dev overrides
│   └── values-prd.yaml         # Prd overrides
├── monitoring/
│   ├── alerts/                 # PrometheusRule CRD
│   └── dashboards/             # Grafana dashboard JSON
├── loadtest/                   # Locust load tests
├── docs/                       # Project documentation
│   ├── diagrams.md             # Architecture diagrams (Mermaid)
│   ├── infrastructure.md       # Infra components reference
│   ├── gitflow.md              # Branching strategy
│   ├── workflows.md            # CI/CD pipeline docs
│   ├── monitoring.md           # Observability stack docs
│   └── security.md             # Security practices
└── README.md                   # This file
```

---

## ⚠️ Manual Steps Required

Everything below must be done **manually** before the pipelines can run. The code uses `HERE_*` placeholders that you need to replace with your actual values.

---

### Step 1: Create GCP Projects

Create **two** GCP projects (or one if you prefer a single project):

```bash
# Dev project
gcloud projects create HERE_GCP_PROJECT_ID_DEV --name="Task Manager Dev"

# Prd project
gcloud projects create HERE_GCP_PROJECT_ID_PRD --name="Task Manager Prd"
```

Enable the required APIs on **both** projects:

```bash
for PROJECT in HERE_GCP_PROJECT_ID_DEV HERE_GCP_PROJECT_ID_PRD; do
  gcloud services enable \
    compute.googleapis.com \
    container.googleapis.com \
    sqladmin.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    secretmanager.googleapis.com \
    servicenetworking.googleapis.com \
    cloudresourcemanager.googleapis.com \
    --project=$PROJECT
done
```

> **Billing**: Make sure both projects have a billing account attached.

---

### Step 2: Create GCS Buckets for Terraform State

Create **two** GCS buckets (one per environment) for Terraform remote state:

```bash
# Dev state bucket
gcloud storage buckets create gs://HERE_GCS_STATE_BUCKET_NAME-dev \
  --project=HERE_GCP_PROJECT_ID_DEV \
  --location=europe-west1 \
  --uniform-bucket-level-access

# Prd state bucket
gcloud storage buckets create gs://HERE_GCS_STATE_BUCKET_NAME-prd \
  --project=HERE_GCP_PROJECT_ID_PRD \
  --location=europe-west1 \
  --uniform-bucket-level-access
```

Enable versioning (recommended):

```bash
gcloud storage buckets update gs://HERE_GCS_STATE_BUCKET_NAME-dev --versioning
gcloud storage buckets update gs://HERE_GCS_STATE_BUCKET_NAME-prd --versioning
```

---

### Step 3: Create the GitHub Repository

```bash
# Create repo on GitHub (via CLI or web UI)
gh repo create HERE_GITHUB_OWNER/HERE_GITHUB_REPO_NAME --private

# Initialize and push
cd IaC
git init
git remote add origin https://github.com/HERE_GITHUB_OWNER/HERE_GITHUB_REPO_NAME.git
git checkout -b main
git add .
git commit -m "feat: initial project structure"
git push -u origin main
```

---

### Step 4: Create Branches (GitFlow)

```bash
git checkout -b develop
git push -u origin develop
```

---

### Step 5: Set Up Branch Protection Rules

Go to **GitHub → Repository → Settings → Branches** and configure:

#### `main` branch:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass (add: `terraform-ci`, `app-ci`)
- ✅ Require branches to be up to date before merging
- ✅ Do not allow deletions

#### `develop` branch:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass (add: `terraform-ci`, `app-ci`)

---

### Step 6: Create GitHub Environments

Go to **GitHub → Repository → Settings → Environments** and create:

#### Environment: `dev`
- No deployment protection rules needed

#### Environment: `prd`
- (Optional) Add **required reviewers** for production approvals

---

### Step 7: Run Terraform Locally (Bootstrap)

Since WIF doesn't exist yet, you need to run Terraform locally for the **first time** to create the WIF resources. After that, GitHub Actions can self-authenticate.

```bash
# Authenticate to GCP
gcloud auth application-default login

# Dev environment
cd terraform/environments/dev
terraform init
terraform apply

# Prd environment
cd ../prd
terraform init
terraform apply
```

> **Important**: After this initial apply, note the Terraform outputs — you'll need them for GitHub environment variables.

---

### Step 8: Configure GitHub Environment Variables

After Terraform has run, set these variables on each GitHub environment:

Go to **GitHub → Settings → Environments → dev/prd → Environment variables**:

| Variable | Where to find it |
|----------|-----------------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_WIF_PROVIDER` | Terraform output: `wif_provider` (format: `projects/PROJECT_NUM/locations/global/workloadIdentityPools/POOL/providers/PROVIDER`) |
| `GCP_SA_EMAIL` | Terraform output: `wif_service_account_email` |
| `GKE_CLUSTER_NAME` | Terraform output: `gke_cluster_name` |
| `GKE_CLUSTER_ZONE` | `europe-west1-b` (dev) or your chosen zone |

---

### Step 9: (Optional) Set Up ARC Runners Variable

Once the ARC controller is running in GKE, set the runner label:

Go to **GitHub → Settings → Variables → Repository variables**:

| Variable | Value |
|----------|-------|
| `RUNNER_LABEL` | `arc-runner-set` (or whatever you named your runner scale set) |

> Until this is set, all workflows default to `ubuntu-latest` (GitHub-hosted runners).

---

### Step 10: Create a GitHub App for ARC

ARC v2 requires a **GitHub App** for runner registration:

1. Go to **GitHub → Settings → Developer settings → GitHub Apps → New GitHub App**
2. Configure:
   - **Name**: `ARC Runner - Task Manager` (must be unique across GitHub)
   - **Homepage URL**: `https://github.com/HERE_GITHUB_OWNER/HERE_GITHUB_REPO_NAME`
   - **Webhook**: Deactivate (uncheck "Active")
   - **Permissions**:
     - Repository: `Actions: Read & Write`, `Administration: Read & Write`, `Metadata: Read-only`
     - Organization: `Self-hosted runners: Read & Write` (if org-level)
3. Click **Create GitHub App**
4. Note the **App ID**
5. Generate a **Private Key** (`.pem` file)
6. Install the App on your repository

Then create a Kubernetes secret in the GKE cluster:

```bash
# Get GKE credentials
gcloud container clusters get-credentials CLUSTER_NAME --zone europe-west1-b --project PROJECT_ID

# Create the secret for ARC
kubectl create secret generic arc-github-app \
  --namespace=runners \
  --from-literal=github_app_id=YOUR_APP_ID \
  --from-literal=github_app_installation_id=YOUR_INSTALLATION_ID \
  --from-file=github_app_private_key=path/to/private-key.pem
```

> **Note**: The Terraform Helm release for ARC references this secret name. Update `terraform/environments/dev/main.tf` (and prd) if you use a different secret name.

---

### Step 11: Configure DNS

Point your domain to the NGINX ingress controller's external IP:

```bash
# Get the external IP
kubectl get svc -n ingress-nginx

# Create DNS A record:
# dev.HERE_APP_DOMAIN → <EXTERNAL_IP> (dev)
# HERE_APP_DOMAIN     → <EXTERNAL_IP> (prd)
```

---

### Step 12: Replace All Placeholders

Search the codebase for all `HERE_*` placeholders and replace them with your actual values:

```powershell
# Find all placeholders (PowerShell)
Get-ChildItem -Recurse -File | Select-String -Pattern "HERE_" | Select-Object Filename, LineNumber, Line
```

| Placeholder | Description | Files |
|-------------|-------------|-------|
| `HERE_GCP_PROJECT_ID_DEV` | GCP project ID for dev | `terraform/environments/dev/terraform.tfvars` |
| `HERE_GCP_PROJECT_ID_PRD` | GCP project ID for prd | `terraform/environments/prd/terraform.tfvars` |
| `HERE_GCS_STATE_BUCKET_NAME` | GCS bucket for Terraform state | `terraform/environments/*/backend.tf` |
| `HERE_GITHUB_OWNER` | GitHub username or org | `terraform/environments/*/terraform.tfvars` |
| `HERE_GITHUB_REPO_NAME` | GitHub repository name | `terraform/environments/*/terraform.tfvars` |
| `HERE_ARTIFACT_REGISTRY_URL` | Artifact Registry URL | `helm/fastapi-app/values.yaml` |
| `HERE_APP_SERVICE_ACCOUNT_EMAIL` | App GCP SA email | `helm/fastapi-app/values.yaml` |
| `HERE_APP_DOMAIN` | Your domain name | `helm/fastapi-app/values-dev.yaml`, `values-prd.yaml` |
| `HERE_CLOUDSQL_CONNECTION_NAME` | Cloud SQL connection string | `helm/fastapi-app/values-dev.yaml`, `values-prd.yaml` |
| `HERE_GRAFANA_ADMIN_PASSWORD` | Grafana prd password | `terraform/helm-releases/monitoring-values-prd.yaml` |
| `HERE_GITHUB_REPO_URL` | Full repo URL for workflows | `.github/workflows/*.yml` (if present) |

---

### Step 13: Deploy the Application

After all the above is done:

```bash
# Create a feature branch
git checkout develop
git checkout -b feature/initial-deploy

# Commit any placeholder replacements
git add .
git commit -m "feat: configure environment-specific values"
git push origin feature/initial-deploy

# Open PR → develop → triggers CI
# Merge PR → triggers deploy to dev

# When dev is validated:
# Open PR: develop → main → triggers CI
# Merge → triggers terraform-apply-prd
# Create tag: git tag v1.0.0 && git push origin v1.0.0 → triggers app-deploy-prd
```

---

### Step 14: Import Grafana Dashboard

```bash
kubectl create configmap grafana-fastapi-dashboard \
  --from-file=fastapi-app-dashboard.json=monitoring/dashboards/fastapi-app-dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | \
  kubectl label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl apply -f -
```

Or import manually via Grafana UI at `http://localhost:3000` (after port-forwarding).

---

### Step 15: Apply Monitoring Alert Rules

```bash
kubectl apply -f monitoring/alerts/fastapi-app-alerts.yaml
```

---

### Step 16: Run Load Tests

```bash
cd loadtest
pip install -r requirements.txt
locust -f locustfile.py --host=https://dev.HERE_APP_DOMAIN
# Open http://localhost:8089 to start the test
```

---

## Quick Reference

### Useful Commands

```bash
# Get GKE credentials
gcloud container clusters get-credentials CLUSTER_NAME --zone europe-west1-b --project PROJECT_ID

# Check pods
kubectl get pods -n app
kubectl get pods -n runners
kubectl get pods -n monitoring

# View logs
kubectl logs -n app deployment/fastapi-app -c fastapi

# Port-forward Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Port-forward the app locally
kubectl port-forward svc/fastapi-app 8000:80 -n app

# Run tests locally
cd app && pip install -r requirements-test.txt && pytest tests/ -v

# Terraform plan (local)
cd terraform/environments/dev && terraform plan

# Helm dry-run
helm upgrade --install fastapi-app helm/fastapi-app \
  -f helm/fastapi-app/values-dev.yaml \
  -n app --dry-run
```

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | API info |
| GET | `/healthz` | Liveness probe |
| GET | `/readyz` | Readiness probe |
| GET | `/metrics` | Prometheus metrics |
| POST | `/api/v1/auth/token` | Get JWT token |
| GET | `/api/v1/tasks` | List tasks |
| POST | `/api/v1/tasks` | Create task |
| GET | `/api/v1/tasks/{id}` | Get task |
| PUT | `/api/v1/tasks/{id}` | Update task |
| DELETE | `/api/v1/tasks/{id}` | Delete task |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/infrastructure.md](docs/infrastructure.md) | Infrastructure components reference |
| [docs/gitflow.md](docs/gitflow.md) | GitFlow branching strategy |
| [docs/workflows.md](docs/workflows.md) | CI/CD pipeline documentation |
| [docs/monitoring.md](docs/monitoring.md) | Monitoring & observability |
| [docs/security.md](docs/security.md) | Security practices |
| [docs/diagrams.md](docs/diagrams.md) | Architecture diagrams (Mermaid) |
