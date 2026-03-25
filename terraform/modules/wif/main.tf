# ==============================================================================
# Workload Identity Federation Module - GitHub Actions OIDC → GCP
# ==============================================================================

# --- Workload Identity Pool ---
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.project_prefix}-github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC authentication"
}

# --- OIDC Provider (GitHub Actions) ---
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC"

  # Only allow tokens from your specific repository
  attribute_condition = "assertion.repository == '${var.github_owner}/${var.github_repo}'"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.actor"       = "assertion.actor"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
    "attribute.ref"         = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- Service Account for CI/CD ---
resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = "${var.project_prefix}-gh-actions"
  display_name = "GitHub Actions CI/CD (${var.environment})"
  description  = "Service account used by GitHub Actions via WIF for ${var.environment} environment"
}

# --- Bind WIF to Service Account (scoped to repo + environment) ---
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/repo:${var.github_owner}/${var.github_repo}:environment:${var.environment}"
}

# --- Grant CI/CD SA necessary project-level roles ---
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset(var.github_actions_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
