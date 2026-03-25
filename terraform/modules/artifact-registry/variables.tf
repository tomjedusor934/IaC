variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}
