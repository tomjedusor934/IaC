variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "github_owner" {
  description = "GitHub repository owner (user or org)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "app_image_tag" {
  description = "Docker image tag for the FastAPI app"
  type        = string
  default     = "latest"
}

# --- GitHub App credentials for ARC runners ---
variable "github_app_id" {
  description = "GitHub App ID for ARC runners"
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID for ARC runners"
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM) for ARC runners"
  type        = string
  sensitive   = true
}

# --- JWT signing key for app auth ---
variable "jwt_secret_key" {
  description = "Secret key for JWT token signing"
  type        = string
  sensitive   = true
}
