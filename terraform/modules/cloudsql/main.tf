# ==============================================================================
# Cloud SQL Module - PostgreSQL with private IP
# ==============================================================================

resource "random_password" "db_password" {
  length  = 24
  special = true
}

resource "google_sql_database_instance" "main" {
  name                = "${var.project_prefix}-postgres"
  project             = var.project_id
  region              = var.region
  database_version    = "POSTGRES_15"
  deletion_protection = var.deletion_protection

  depends_on = [var.private_service_access_connection]

  settings {
    tier              = var.db_tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_self_link
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.environment == "prd"
      start_time                     = "03:00"
      transaction_log_retention_days = var.environment == "prd" ? 7 : 3

      backup_retention_settings {
        retained_backups = var.environment == "prd" ? 30 : 7
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 3
      update_track = "stable"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    user_labels = var.labels
  }
}

resource "google_sql_database" "app" {
  name     = "taskmanager"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name     = "taskmanager"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
}

# Store the password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_prefix}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
