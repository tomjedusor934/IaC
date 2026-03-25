variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_prefix" {
  description = "Prefix for resource names (e.g., taskmanager-dev)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "gke_subnet_cidr" {
  description = "Primary CIDR for the GKE subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services"
  type        = string
  default     = "10.8.0.0/20"
}
