# ==============================================================================
# VPC Module - Network, Subnets, Cloud Router, Cloud NAT, Private Service Access
# ==============================================================================

resource "google_compute_network" "main" {
  name                    = "${var.project_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# --- GKE Subnet with secondary ranges for pods and services ---
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.project_prefix}-gke-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.gke_subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# --- Cloud Router (required for Cloud NAT) ---
resource "google_compute_router" "main" {
  name    = "${var.project_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}

# --- Cloud NAT (outbound internet for private GKE nodes) ---
resource "google_compute_router_nat" "main" {
  name                               = "${var.project_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Private Service Access (for Cloud SQL private IP) ---
resource "google_compute_global_address" "private_service_access" {
  name          = "${var.project_prefix}-psa-range"
  project       = var.project_id
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

# --- Firewall: Allow health checks from GCP load balancers ---
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.project_prefix}-allow-health-checks"
  project = var.project_id
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

# --- Firewall: Allow internal traffic within VPC ---
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_prefix}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.id

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.gke_subnet_cidr,
    var.pods_cidr,
    var.services_cidr,
  ]
}
