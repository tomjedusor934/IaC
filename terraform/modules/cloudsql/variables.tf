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

variable "environment" {
  description = "Environment name (dev or prd)"
  type        = string
}

variable "network_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "private_service_access_connection" {
  description = "Private service access connection (dependency)"
  type        = any
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-2-8192"
}

variable "availability_type" {
  description = "Cloud SQL availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "ZONAL"
}

variable "disk_size" {
  description = "Initial disk size in GB"
  type        = number
  default     = 10
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}
