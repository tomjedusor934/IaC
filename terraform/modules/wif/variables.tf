variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prd)"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner (user or org)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_actions_roles" {
  description = "List of IAM roles to grant to the GitHub Actions service account"
  type        = list(string)
  default = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser",
  ]
}
