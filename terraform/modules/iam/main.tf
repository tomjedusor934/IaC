# ==============================================================================
# IAM Module - Application Service Account + GKE Workload Identity binding
# ==============================================================================

# --- Application Service Account (used by FastAPI pods via GKE Workload Identity) ---
resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "${var.project_prefix}-app-sa"
  display_name = "FastAPI App SA (${var.environment})"
  description  = "Service account for FastAPI application pods in ${var.environment}"
}

# --- Grant Cloud SQL client role to app SA ---
resource "google_project_iam_member" "app_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# --- Grant Secret Manager access to app SA ---
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# --- GKE Workload Identity binding ---
# Allows K8s ServiceAccount to impersonate the GCP ServiceAccount
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}
