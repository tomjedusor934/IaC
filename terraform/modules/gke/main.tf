# ==============================================================================
# GKE Module - Private Cluster + Node Pools (default, app, runner)
# ==============================================================================

resource "google_container_cluster" "main" {
  name     = "${var.project_prefix}-gke"
  project  = var.project_id
  location = var.region

  # We manage node pools separately
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnet_id

  # VPC-native cluster (alias IPs)
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  # Master authorized networks
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Dataplane V2 for built-in network policy support
  datapath_provider = "ADVANCED_DATAPATH"

  # Workload Identity for pod-level GCP auth
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Binary authorization (optional, good security practice)
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Cluster addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = true # Using Dataplane V2 instead
    }
    dns_cache_config {
      enabled = true
    }
  }

  # Maintenance window (off-peak)
  maintenance_policy {
    recurring_window {
      start_time = "2025-01-01T03:00:00Z"
      end_time   = "2025-01-01T07:00:00Z"
      recurrence = "FREQ=DAILY"
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Database encryption for etcd
  database_encryption {
    state    = "DECRYPTED" # Set to ENCRYPTED + key_name if you configure a KMS key
  }

  resource_labels = var.labels

  deletion_protection = var.deletion_protection
}

# --- Default/System Node Pool ---
resource "google_container_node_pool" "default" {
  name     = "default-pool"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.main.name

  initial_node_count = var.default_pool_min_count

  autoscaling {
    min_node_count = var.default_pool_min_count
    max_node_count = var.default_pool_max_count
  }

  node_config {
    machine_type = var.default_pool_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["gke-node", "${var.project_prefix}-gke-default"]

    labels = merge(var.labels, {
      pool = "default"
    })

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# --- Application Node Pool ---
resource "google_container_node_pool" "app" {
  name     = "app-pool"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.main.name

  initial_node_count = var.app_pool_min_count

  autoscaling {
    min_node_count = var.app_pool_min_count
    max_node_count = var.app_pool_max_count
  }

  node_config {
    machine_type = var.app_pool_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["gke-node", "${var.project_prefix}-gke-app"]

    labels = merge(var.labels, {
      pool = "app"
    })

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# --- Runner Node Pool (scales to zero) ---
resource "google_container_node_pool" "runner" {
  name     = "runner-pool"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.main.name

  initial_node_count = 0

  autoscaling {
    min_node_count = 0
    max_node_count = var.runner_pool_max_count
  }

  node_config {
    machine_type = var.runner_pool_machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Taint: only runner pods can schedule here
    taint {
      key    = "workload"
      value  = "runner"
      effect = "NO_SCHEDULE"
    }

    tags = ["gke-node", "${var.project_prefix}-gke-runner"]

    labels = merge(var.labels, {
      pool = "runner"
    })

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
