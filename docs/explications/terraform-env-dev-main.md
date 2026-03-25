# Explication : `terraform/environments/dev/main.tf`

C'est le **chef d'orchestre** de l'environnement dev. Il appelle tous les modules et installe toutes les applications sur le cluster.

---

## Vue d'ensemble

Ce fichier fait tout dans l'ordre :
1. Crée le réseau (VPC)
2. Crée le cluster Kubernetes (GKE)
3. Crée la base de données (Cloud SQL)
4. Crée le registre Docker (Artifact Registry)
5. Configure l'authentification GitHub → GCP (WIF)
6. Configure l'authentification Pods → GCP (IAM)
7. Crée les namespaces Kubernetes
8. Installe les applications via Helm

---

## Section par section

### Les variables locales

```hcl
locals {
  project_prefix = "taskmanager-${var.environment}"
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "taskmanager"
  }
}
```
- `project_prefix` : préfixe pour nommer les ressources (ex: `taskmanager-dev-postgres`)
- `labels` : étiquettes appliquées à toutes les ressources pour le suivi et la facturation

### 1. Module VPC

```hcl
module "vpc" {
  source = "../../modules/vpc"

  gke_subnet_cidr = "10.0.0.0/20"
  pods_cidr       = "10.4.0.0/14"
  services_cidr   = "10.8.0.0/20"
}
```
Appelle le module VPC avec les plages d'adresses IP pour le sous-réseau GKE, les pods et les services. Ces plages sont suffisamment grandes pour le dev.

### 2. Module GKE

```hcl
module "gke" {
  source = "../../modules/gke"

  master_cidr         = "172.16.0.0/28"
  release_channel     = "REGULAR"
  deletion_protection = false

  default_pool_machine_type = "e2-standard-2"
  default_pool_min_count    = 1
  default_pool_max_count    = 2

  app_pool_machine_type = "e2-standard-2"
  app_pool_min_count    = 1
  app_pool_max_count    = 2

  runner_pool_machine_type = "e2-standard-4"
  runner_pool_max_count    = 3
}
```
Paramètres dev du cluster :
- **Machines petites** : `e2-standard-2` (2 vCPU, 8 Go RAM) pour les pools default et app
- **Peu de nœuds** : min 1, max 2 par pool
- **Pas de protection contre la suppression** : on peut détruire le cluster facilement en dev
- **Runners plus gros** : `e2-standard-4` car les builds CI/CD sont gourmands

### 3. Module Cloud SQL

```hcl
module "cloudsql" {
  db_tier           = "db-custom-1-3840"   # 1 vCPU, 3.75 Go RAM
  availability_type = "ZONAL"                # Pas de réplica
  disk_size         = 10                     # 10 Go
  deletion_protection = false
}
```
Base de données **petite** pour le dev : 1 vCPU, stockage minimal, pas de haute disponibilité.

### 4. Module Artifact Registry

```hcl
module "artifact_registry" {
  source = "../../modules/artifact-registry"
  # ...
}
```
Simple appel au module, pas de paramètre spécial pour le dev.

### 5. Module WIF

```hcl
module "wif" {
  source = "../../modules/wif"

  github_actions_roles = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser",
  ]
}
```
Configure WIF avec les 4 rôles nécessaires au CI/CD.

### 6. Module IAM

```hcl
module "iam" {
  k8s_namespace       = "app"
  k8s_service_account = "fastapi-app"
}
```
Lie le ServiceAccount Kubernetes `fastapi-app` au ServiceAccount GCP.

### 7. Namespaces Kubernetes

```hcl
resource "kubernetes_namespace" "app" {
  metadata { name = "app" }
  depends_on = [module.gke]
}

resource "kubernetes_namespace" "runners" {
  metadata { name = "runners" }
}

resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

resource "kubernetes_namespace" "ingress" {
  metadata { name = "ingress-nginx" }
}
```
Crée 4 namespaces dans le cluster :
| Namespace | Contenu |
|-----------|---------|
| `app` | L'application FastAPI |
| `runners` | Les runners GitHub Actions self-hosted |
| `monitoring` | Prometheus, Grafana, alertes |
| `ingress-nginx` | Le contrôleur d'entrée (load balancer) |

`depends_on = [module.gke]` : le cluster doit exister avant de créer les namespaces !

### 8. Helm Releases

#### NGINX Ingress Controller

```hcl
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"
  namespace  = kubernetes_namespace.ingress.metadata[0].name
```
Le **contrôleur Ingress** reçoit le trafic HTTP depuis Internet et le route vers les bons services. Il crée un **Load Balancer GCP** (`service.type = LoadBalancer`).

#### cert-manager

```hcl
resource "helm_release" "cert_manager" {
  chart   = "cert-manager"
  version = "v1.16.1"
```
**cert-manager** génère et renouvelle automatiquement des certificats TLS (HTTPS) via Let's Encrypt. `installCRDs = true` installe les Custom Resource Definitions nécessaires.

#### ARC Controller + Runner Scale Set

```hcl
resource "helm_release" "arc_controller" {
  chart   = "oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller"
  version = "0.9.3"
}
```
**ARC** (Actions Runner Controller) permet d'exécuter les jobs GitHub Actions sur ton propre cluster GKE au lieu d'utiliser les runners GitHub partagés.

```hcl
resource "kubernetes_secret" "github_app_secret" {
  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }
}
```
Les credentials de la GitHub App sont stockées en tant que **Secret Kubernetes**. Le runner scale set les utilise pour s'authentifier auprès de GitHub.

```hcl
resource "helm_release" "arc_runner_set" {
  values = [yamlencode({
    minRunners = 0       # Pas de runner quand y'a rien à faire
    maxRunners = 5       # Max 5 runners simultanés
    runnerScaleSetName = "gke-runners"

    template = {
      spec = {
        tolerations = [{ key = "workload", value = "runner" }]
        nodeSelector = { "cloud.google.com/gke-nodepool" = "runner-pool" }
      }
    }
  })]
}
```
Les runners :
- Tournent sur le **runner-pool** uniquement (grâce au `nodeSelector` et `tolerations`)
- **Autoscalent** de 0 à 5 instances selon la demande
- Utilisent l'image officielle GitHub Actions

#### kube-prometheus-stack

```hcl
resource "helm_release" "kube_prometheus_stack" {
  chart   = "kube-prometheus-stack"
  version = "62.7.0"

  values = [
    file("${path.module}/../../helm-releases/monitoring-values-dev.yaml")
  ]
}
```
Installe **Prometheus** (collecte de métriques), **Grafana** (dashboards) et **Alertmanager** (alertes). Les valeurs spécifiques au dev sont dans un fichier YAML séparé.

#### External Secrets Operator

```hcl
resource "helm_release" "external_secrets" {
  chart   = "external-secrets"
  version = "0.10.5"
}
```
**External Secrets Operator** synchronise les secrets depuis **GCP Secret Manager** vers des Secrets Kubernetes. Exemple : le mot de passe de la base de données est dans Secret Manager, et ESO le copie automatiquement dans un Secret K8s que le pod peut lire.

#### L'application FastAPI

```hcl
resource "helm_release" "fastapi_app" {
  chart     = "${path.module}/../../../helm/fastapi-app"
  namespace = kubernetes_namespace.app.metadata[0].name

  values = [
    file("${path.module}/../../../helm/fastapi-app/values-dev.yaml")
  ]
```
Installe l'application FastAPI en utilisant le **chart Helm custom** avec les valeurs de dev.

```hcl
  set {
    name  = "image.repository"
    value = module.artifact_registry.repository_url
  }

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = module.iam.app_service_account_email
  }
```
Les valeurs dynamiques sont injectées via `set` :
- L'URL du registre Docker (pour que K8s sache d'où tirer l'image)
- L'annotation Workload Identity (pour que le pod puisse accéder à GCP)

```hcl
  set {
    name  = "env.DATABASE_HOST"
    value = "127.0.0.1"   # Cloud SQL Auth Proxy sidecar
  }

  set {
    name  = "cloudSqlProxy.instanceConnectionName"
    value = module.cloudsql.instance_connection_name
  }
```
L'application se connecte à la base de données via le **Cloud SQL Auth Proxy** (un sidecar container). Le host est `127.0.0.1` car le proxy tourne dans le même pod.

---

## Pourquoi ce fichier est nécessaire ?

C'est le **point d'entrée** de tout l'environnement dev. Sans lui, rien ne se crée. Il orchestre l'appel de tous les modules dans le bon ordre et configure toutes les connexions entre les composants.
