# Explication : `terraform/modules/vpc/`

Ce dossier contient 3 fichiers (`main.tf`, `variables.tf`, `outputs.tf`) qui forment un **module Terraform** pour créer toute la couche réseau sur GCP.

---

## Qu'est-ce qu'un VPC ?

Un **VPC** (Virtual Private Cloud) est un réseau privé virtuel dans le cloud. C'est comme un réseau local d'entreprise, mais dans le cloud. Toutes tes ressources (serveurs, bases de données, clusters) communiquent à travers ce réseau.

---

## Fichier : `variables.tf`

Ce fichier définit les **paramètres d'entrée** du module — les informations qu'il a besoin pour fonctionner.

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}
```
L'identifiant de ton projet GCP (ex: `mon-projet-123`). Chaque ressource GCP appartient à un projet.

```hcl
variable "project_prefix" {
  description = "Prefix for resource names (e.g., taskmanager-dev)"
  type        = string
}
```
Un préfixe ajouté à tous les noms de ressources (ex: `taskmanager-dev`). Ça les rend uniques et identifiables.

```hcl
variable "region" {
  description = "GCP region"
  type        = string
}
```
La région GCP où créer le réseau (ex: `europe-west1` = Belgique).

```hcl
variable "gke_subnet_cidr" {
  description = "Primary CIDR for the GKE subnet"
  type        = string
  default     = "10.0.0.0/20"
}
```
La **plage d'adresses IP** du sous-réseau principal. `/20` donne 4096 adresses (10.0.0.0 à 10.0.15.255).

> **CIDR** : notation qui définit une plage d'adresses IP. Le nombre après le `/` indique combien de bits sont fixes.

```hcl
variable "pods_cidr" {
  default     = "10.4.0.0/14"
}
```
Plage secondaire pour les **pods** Kubernetes. `/14` = 262 144 adresses (les pods en consomment beaucoup).

```hcl
variable "services_cidr" {
  default     = "10.8.0.0/20"
}
```
Plage secondaire pour les **services** Kubernetes (les adresses IP internes des services).

---

## Fichier : `main.tf`

C'est le cœur du module — il crée les ressources.

### 1. Le VPC lui-même

```hcl
resource "google_compute_network" "main" {
  name                    = "${var.project_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}
```

- **`google_compute_network`** : crée un réseau VPC sur GCP
- **`auto_create_subnetworks = false`** : on crée nos propres sous-réseaux manuellement (mode « custom »). Si `true`, GCP créerait automatiquement un sous-réseau dans chaque région, ce qu'on ne veut pas.
- **`routing_mode = "REGIONAL"`** : les routes réseau sont limitées à la région (plus sûr et suffisant pour notre cas)

### 2. Le sous-réseau GKE

```hcl
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.project_prefix}-gke-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.gke_subnet_cidr
  private_ip_google_access = true
```

- **`ip_cidr_range`** : la plage d'adresses IP principales (10.0.0.0/20)
- **`private_ip_google_access = true`** : permet aux machines SANS IP publique d'accéder aux services Google (Cloud SQL, Artifact Registry, etc.)

```hcl
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
```
Les **plages secondaires** sont spécifiques à GKE. Kubernetes a besoin de plages IP séparées pour :
- Les **pods** (chaque pod reçoit sa propre IP)
- Les **services** (chaque Service Kubernetes reçoit sa propre IP interne)

```hcl
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
```
Active les **VPC Flow Logs** : enregistre le trafic réseau pour le debugging et la sécurité.
- `flow_sampling = 0.5` : enregistre 50% du trafic (compromis entre coût et visibilité)

### 3. Cloud Router

```hcl
resource "google_compute_router" "main" {
  name    = "${var.project_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}
```
Un **Cloud Router** est nécessaire pour Cloud NAT (étape suivante). C'est un routeur réseau qui gère le routage dynamique.

### 4. Cloud NAT

```hcl
resource "google_compute_router_nat" "main" {
  name                               = "${var.project_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
```

**Cloud NAT** (Network Address Translation) permet aux machines **sans IP publique** d'accéder à Internet en sortie. C'est essentiel parce que notre cluster GKE est **privé** (les nœuds n'ont pas d'IP publique), mais ils ont besoin d'Internet pour :
- Télécharger des images Docker
- Accéder aux registres de paquets
- Communiquer avec des APIs externes

- `AUTO_ONLY` : GCP alloue automatiquement les IP NAT
- `ALL_SUBNETWORKS_ALL_IP_RANGES` : applique le NAT à tout le trafic sortant

### 5. Private Service Access (PSA)

```hcl
resource "google_compute_global_address" "private_service_access" {
  name          = "${var.project_prefix}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
}
```

Le **Private Service Access** crée un lien privé entre ton VPC et les services managés de Google (notamment Cloud SQL). Sans ça, Cloud SQL ne pourrait pas avoir une IP privée dans ton réseau.

- On réserve d'abord une **plage d'adresses** pour le peering (`/20` = 4096 adresses)
- Puis on crée la **connexion de peering** avec le service `servicenetworking.googleapis.com`

### 6. Règles de firewall

```hcl
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.project_prefix}-allow-health-checks"
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8000", "8080", "10256"]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]

  target_tags = ["gke-node"]
}
```
Autorise les **health checks** des load balancers GCP :
- Les plages `130.211.0.0/22` et `35.191.0.0/16` sont les IP des load balancers Google
- Les ports autorisés incluent HTTP (80), HTTPS (443), l'app (8000/8080) et kubelet (10256)
- `target_tags` : s'applique uniquement aux machines avec le tag `gke-node`

```hcl
resource "google_compute_firewall" "allow_internal" {
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }

  source_ranges = [
    var.gke_subnet_cidr,
    var.pods_cidr,
    var.services_cidr,
  ]
}
```
Autorise **tout le trafic interne** (TCP, UDP, ICMP) entre les nœuds, les pods et les services. Sans cette règle, les pods ne pourraient pas communiquer entre eux.

---

## Fichier : `outputs.tf`

Les **outputs** exportent des valeurs pour que d'autres modules puissent les utiliser.

```hcl
output "network_id" {
  value = google_compute_network.main.id
}
output "gke_subnet_id" {
  value = google_compute_subnetwork.gke.id
}
output "private_service_access_connection" {
  value = google_service_networking_connection.private_service_access
}
```
- `network_id` : utilisé par le module GKE pour connecter le cluster au VPC
- `gke_subnet_id` : utilisé par le module GKE pour placer les nœuds dans ce sous-réseau
- `private_service_access_connection` : utilisé par le module Cloud SQL pour la dépendance d'ordonnancement

---

## Pourquoi ce module est nécessaire ?

Le réseau est la **fondation** de toute l'infrastructure. Sans VPC :
- Pas de cluster GKE (il a besoin d'un réseau)
- Pas de Cloud SQL privé (il a besoin de PSA)
- Pas de communication entre les services
- Pas d'accès Internet pour les nœuds privés (via Cloud NAT)

C'est le premier module qui doit être créé, et tous les autres en dépendent.
