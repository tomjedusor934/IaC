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

variable "k8s_namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "app"
}

variable "k8s_service_account" {
  description = "Kubernetes ServiceAccount name for the app"
  type        = string
  default     = "fastapi-app"
}
