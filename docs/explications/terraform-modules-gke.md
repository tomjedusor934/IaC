# Explication : `terraform/modules/gke/`

Ce module crée un **cluster GKE** (Google Kubernetes Engine) avec 3 pools de nœuds.

---

## Qu'est-ce que GKE ?

GKE est le service Kubernetes managé de Google. **Kubernetes** (K8s) est un orchestrateur de conteneurs : il lance tes applications Docker sur un groupe de machines (les « nœuds »), les surveille, les redémarre si elles plantent, et les scale automatiquement.

GKE s'occupe de la partie « cerveau » de Kubernetes (le control plane) pour toi. Tu ne gères que les nœuds.

---

## Fichier : `variables.tf`

```hcl
variable "network_id" { ... }
variable "subnet_id" { ... }
```
Références au VPC et au sous-réseau créés par le module VPC. C'est comme dire « connecte ce cluster à ce réseau ».

```hcl
variable "master_cidr" {
  default = "172.16.0.0/28"
}
```
La plage IP du **control plane** (le « cerveau » de Kubernetes). C'est un réseau séparé géré par Google. `/28` = 16 adresses, c'est suffisant.

```hcl
variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [{ cidr_block = "0.0.0.0/0", display_name = "all" }]
}
```
Liste des réseaux autorisés à communiquer avec le master Kubernetes. `0.0.0.0/0` = tout le monde (à restreindre en production !).

```hcl
variable "release_channel" {
  default = "REGULAR"
}
```
Canal de mise à jour : `RAPID` (dernières versions), `REGULAR` (stable), `STABLE` (très conservateur). On utilise REGULAR en dev et STABLE en prod.

```hcl
variable "deletion_protection" {
  default = false
}
```
Si `true`, empêche la suppression accidentelle du cluster. Activé en production.

Les variables `*_pool_machine_type`, `*_pool_min/max_count` configurent les types de machines et la taille de chaque pool de nœuds.

---

## Fichier : `main.tf`

### Le cluster GKE

```hcl
resource "google_container_cluster" "main" {
  name     = "${var.project_prefix}-gke"
  location = var.region
```
Crée un cluster GKE **régional** (les nœuds sont répartis sur 3 zones de la région pour la haute disponibilité).

```hcl
  remove_default_node_pool = true
  initial_node_count       = 1
```
GKE crée toujours un pool de nœuds par défaut. On le supprime immédiatement (`remove_default_node_pool = true`) pour créer nos propres pools personnalisés. `initial_node_count = 1` est un placeholder obligatoire.

```hcl
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
```
Active le mode **VPC-native** : les pods et services reçoivent de vraies IP du VPC (les plages secondaires définies dans le module VPC). C'est obligatoire pour les clusters modernes.

```hcl
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }
```
**Cluster privé** :
- `enable_private_nodes = true` : les nœuds n'ont **pas d'IP publique** (sécurité !)
- `enable_private_endpoint = false` : le master EST accessible depuis Internet (sinon il faut un VPN pour `kubectl`)
- `master_ipv4_cidr_block` : plage IP du control plane

```hcl
  datapath_provider = "ADVANCED_DATAPATH"
```
Active **Dataplane V2** (basé sur Cilium/eBPF). Avantages :
- NetworkPolicy intégré (pas besoin d'installer Calico)
- Meilleures performances réseau
- Meilleure observabilité

```hcl
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
```
Active **Workload Identity** : permet aux pods Kubernetes d'utiliser des comptes de service GCP sans clé JSON. Les pods s'authentifient via l'identité de leur ServiceAccount Kubernetes.

```hcl
  addons_config {
    http_load_balancing { disabled = false }
    horizontal_pod_autoscaling { disabled = false }
    network_policy_config { disabled = true }  # Dataplane V2 le gère
    dns_cache_config { enabled = true }
  }
```
**Addons** activés :
- **HTTP Load Balancing** : intégré avec les Ingress Google
- **Horizontal Pod Autoscaling** : permet le HPA (autoscaling des pods)
- **DNS Cache** : accélère la résolution DNS dans le cluster

```hcl
  maintenance_policy {
    recurring_window {
      start_time = "2025-01-01T03:00:00Z"
      end_time   = "2025-01-01T07:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }
```
**Fenêtre de maintenance** : GKE peut mettre à jour le cluster uniquement entre 3h et 7h du matin, les samedis et dimanches. Ça évite les perturbations pendant les heures de travail.

```hcl
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus { enabled = true }
  }
```
Active la collecte de **logs** et de **métriques** pour le cluster. Google Managed Prometheus collecte automatiquement les métriques.

```hcl
  release_channel { channel = var.release_channel }
  deletion_protection = var.deletion_protection
```

### Les 3 Pools de Nœuds

#### Pool « default » (système)

```hcl
resource "google_container_node_pool" "default" {
  name     = "default-pool"
  ...
  autoscaling {
    min_node_count = var.default_pool_min_count
    max_node_count = var.default_pool_max_count
  }
  node_config {
    machine_type = var.default_pool_machine_type  # e2-standard-2
    disk_size_gb = 50
```
Pour les workloads système de Kubernetes (DNS, kube-proxy, etc.).

#### Pool « app » (application)

```hcl
resource "google_container_node_pool" "app" {
  name = "app-pool"
  ...
  node_config {
    machine_type = var.app_pool_machine_type  # e2-standard-2 (dev) / e2-standard-4 (prd)
```
Pour les pods de l'application FastAPI. Taille ajustable entre dev et prd.

#### Pool « runner » (CI/CD)

```hcl
resource "google_container_node_pool" "runner" {
  name = "runner-pool"
  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = var.runner_pool_max_count
  }

  node_config {
    machine_type = var.runner_pool_machine_type  # e2-standard-4
    disk_size_gb = 100

    taint {
      key    = "workload"
      value  = "runner"
      effect = "NO_SCHEDULE"
    }
```
Pour les runners CI/CD auto-hébergés (ARC).

Points clés :
- **`initial_node_count = 0`** + **`min = 0`** : peut scaler à zéro (pas de coût quand aucun job CI/CD ne tourne !)
- **`taint`** : un « poison » qui empêche les pods normaux de se placer ici. Seuls les pods avec une **toleration** correspondante peuvent y aller. Ça garantit que ce pool est réservé aux runners.
- **`disk_size_gb = 100`** : les runners ont besoin de plus d'espace (builds Docker, etc.)

#### Configuration commune à tous les pools

```hcl
    workload_metadata_config { mode = "GKE_METADATA" }
```
Active Workload Identity sur les nœuds.

```hcl
    metadata = {
      disable-legacy-endpoints = "true"
    }
```
Désactive les anciens endpoints de métadonnées (sécurité — empêche les attaques SSRF).

```hcl
  management {
    auto_repair  = true
    auto_upgrade = true
  }
```
GKE répare automatiquement les nœuds cassés et les met à jour.

---

## Fichier : `outputs.tf`

```hcl
output "cluster_name" { ... }
output "cluster_endpoint" { ... }      # sensible
output "cluster_ca_certificate" { ... } # sensible
output "cluster_location" { ... }
output "workload_identity_pool" { ... }
```
Exportés pour :
- Les providers Kubernetes et Helm (pour se connecter au cluster)
- Les workflows GitHub Actions (pour `kubectl`)
- Le module IAM (pour configurer Workload Identity)

---

## Pourquoi ce module est nécessaire ?

Le cluster GKE est le moteur central de toute l'architecture. Il héberge :
- L'application FastAPI (pool app)
- Les runners CI/CD (pool runner)
- Le monitoring Prometheus/Grafana (pool default)
- L'ingress controller NGINX (pool default)

Sans ce module, il n'y a tout simplement nulle part où exécuter les conteneurs.
