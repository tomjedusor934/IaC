# ==============================================================================
# DEV Environment - Main orchestration
# ==============================================================================

locals {
  project_prefix = "taskmanager-${var.environment}"
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "taskmanager"
  }
}

# ==============================================================================
# 1. Networking (VPC, Subnets, NAT, PSA)
# ==============================================================================
module "vpc" {
  source = "../../modules/vpc"

  project_id     = var.project_id
  project_prefix = local.project_prefix
  region         = var.region
  gke_subnet_cidr = "10.0.0.0/20"
  pods_cidr       = "10.4.0.0/14"
  services_cidr   = "10.8.0.0/20"
}

# ==============================================================================
# 2. GKE Cluster + Node Pools
# ==============================================================================
module "gke" {
  source = "../../modules/gke"

  project_id     = var.project_id
  project_prefix = local.project_prefix
  region         = "${var.region}-b" # Pour éviter les GCE_STOCKOUT et limite de quota SSD en régional
  network_id     = module.vpc.network_id
  subnet_id      = module.vpc.gke_subnet_id

  master_cidr             = "172.16.0.0/28"
  release_channel         = "REGULAR"
  deletion_protection     = false

  # DEV: small pools
  default_pool_machine_type = "e2-standard-2"
  default_pool_min_count    = 1
  default_pool_max_count    = 2

  app_pool_machine_type = "e2-standard-2"
  app_pool_min_count    = 1
  app_pool_max_count    = 2

  runner_pool_machine_type = "e2-standard-4"
  runner_pool_max_count    = 3

  labels = local.labels
}

# ==============================================================================
# 3. Cloud SQL (PostgreSQL)
# ==============================================================================
module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id        = var.project_id
  project_prefix    = local.project_prefix
  region            = var.region
  environment       = var.environment
  network_self_link = module.vpc.network_self_link

  private_service_access_connection = module.vpc.private_service_access_connection

  db_tier           = "db-custom-1-3840" # Small for dev
  availability_type = "ZONAL"
  disk_size         = 10
  deletion_protection = false

  labels = local.labels
}

# ==============================================================================
# 4. Artifact Registry
# ==============================================================================
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id     = var.project_id
  project_prefix = local.project_prefix
  region         = var.region
  labels         = local.labels
}

# ==============================================================================
# 5. Workload Identity Federation (GitHub Actions → GCP)
# ==============================================================================
module "wif" {
  source = "../../modules/wif"

  project_id     = var.project_id
  project_prefix = local.project_prefix
  environment    = var.environment
  github_owner   = var.github_owner
  github_repo    = var.github_repo

  github_actions_roles = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser",
  ]
}

# ==============================================================================
# 6. IAM (Application Service Account + GKE Workload Identity)
# ==============================================================================
module "iam" {
  source = "../../modules/iam"

  project_id          = var.project_id
  project_prefix      = local.project_prefix
  environment         = var.environment
  k8s_namespace       = "app"
  k8s_service_account = "fastapi-app"

  depends_on = [module.gke]
}

# ==============================================================================
# 7. Kubernetes Namespaces
# ==============================================================================
resource "kubernetes_namespace" "app" {
  metadata {
    name = "app"
    labels = local.labels
  }
  depends_on = [module.gke]
}

resource "kubernetes_namespace" "runners" {
  metadata {
    name = "runners"
    labels = local.labels
  }
  depends_on = [module.gke]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = local.labels
  }
  depends_on = [module.gke]
}

resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-nginx"
    labels = local.labels
  }
  depends_on = [module.gke]
}

# ==============================================================================
# 8. Helm Releases
# ==============================================================================

# --- NGINX Ingress Controller ---
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"
  namespace  = kubernetes_namespace.ingress.metadata[0].name

  set {
    name  = "controller.replicaCount"
    value = "1"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# --- cert-manager (for TLS certificates) ---
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.16.1"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }
}

# --- ARC: Actions Runner Controller ---
resource "helm_release" "arc_controller" {
  name       = "arc-controller"
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
  version    = "0.9.3"
  namespace  = kubernetes_namespace.runners.metadata[0].name

  set {
    name  = "replicaCount"
    value = "1"
  }
}

# --- ARC: Runner Scale Set ---
resource "kubernetes_secret" "github_app_secret" {
  metadata {
    name      = "github-app-secret"
    namespace = kubernetes_namespace.runners.metadata[0].name
  }

  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }

  depends_on = [module.gke]
}

resource "helm_release" "arc_runner_set" {
  name       = "arc-runner-set"
  chart      = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set"
  version    = "0.9.3"
  namespace  = kubernetes_namespace.runners.metadata[0].name

  values = [
    yamlencode({
      githubConfigUrl    = "https://github.com/${var.github_owner}/${var.github_repo}"
      githubConfigSecret = kubernetes_secret.github_app_secret.metadata[0].name
      minRunners         = 0
      maxRunners         = 5
      runnerScaleSetName = "gke-runners"

      template = {
        spec = {
          tolerations = [{
            key      = "workload"
            operator = "Equal"
            value    = "runner"
            effect   = "NoSchedule"
          }]
          nodeSelector = {
            "cloud.google.com/gke-nodepool" = "runner-pool"
          }
          containers = [{
            name  = "runner"
            image = "ghcr.io/actions/actions-runner:latest"
            resources = {
              requests = {
                cpu    = "500m"
                memory = "1Gi"
              }
              limits = {
                cpu    = "2"
                memory = "4Gi"
              }
            }
          }]
        }
      }
    })
  ]

  depends_on = [helm_release.arc_controller]
}

# --- kube-prometheus-stack (Prometheus + Grafana) ---
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "62.7.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    file("${path.module}/../../helm-releases/monitoring-values-dev.yaml")
  ]
}

# --- External Secrets Operator ---
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.5"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# --- FastAPI Application (custom chart) ---
resource "helm_release" "fastapi_app" {
  name      = "fastapi-app"
  chart     = "${path.module}/../../../helm/fastapi-app"
  namespace = kubernetes_namespace.app.metadata[0].name
  wait      = false

  values = [
    file("${path.module}/../../../helm/fastapi-app/values-dev.yaml")
  ]

  set {
    name  = "image.tag"
    value = var.app_image_tag
  }

  set {
    name  = "image.repository"
    value = module.artifact_registry.repository_url
  }

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = module.iam.app_service_account_email
  }

  set_sensitive {
    name  = "env.JWT_SECRET_KEY"
    value = var.jwt_secret_key
  }

  set {
    name  = "env.DATABASE_HOST"
    value = "127.0.0.1" # Cloud SQL Auth Proxy sidecar
  }

  set {
    name  = "env.DATABASE_NAME"
    value = module.cloudsql.database_name
  }

  set {
    name  = "env.DATABASE_USER"
    value = module.cloudsql.database_user
  }

  set {
    name  = "cloudSqlProxy.instanceConnectionName"
    value = module.cloudsql.instance_connection_name
  }

  depends_on = [
    helm_release.ingress_nginx,
    helm_release.cert_manager,
    module.cloudsql,
  ]
}
