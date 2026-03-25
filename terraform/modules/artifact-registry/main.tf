# ==============================================================================
# Artifact Registry Module - Docker repository for container images
# ==============================================================================

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.project_prefix}-docker"
  description   = "Docker container registry for ${var.project_prefix}"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  labels = var.labels
}
