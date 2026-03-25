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

variable "network_id" {
  description = "VPC network ID"
  type        = string
}

variable "subnet_id" {
  description = "GKE subnet ID"
  type        = string
}

variable "master_cidr" {
  description = "CIDR block for the GKE master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDR blocks authorized to access the GKE master"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all" # Restrict this in production!
    }
  ]
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the cluster"
  type        = bool
  default     = false
}

# --- Default pool ---
variable "default_pool_machine_type" {
  description = "Machine type for the default node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "default_pool_min_count" {
  description = "Min nodes in the default pool"
  type        = number
  default     = 1
}

variable "default_pool_max_count" {
  description = "Max nodes in the default pool"
  type        = number
  default     = 2
}

# --- App pool ---
variable "app_pool_machine_type" {
  description = "Machine type for the app node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "app_pool_min_count" {
  description = "Min nodes in the app pool"
  type        = number
  default     = 1
}

variable "app_pool_max_count" {
  description = "Max nodes in the app pool"
  type        = number
  default     = 3
}

# --- Runner pool ---
variable "runner_pool_machine_type" {
  description = "Machine type for the runner node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "runner_pool_max_count" {
  description = "Max nodes in the runner pool (min is always 0)"
  type        = number
  default     = 3
}

variable "labels" {
  description = "Labels to apply to GKE resources"
  type        = map(string)
  default     = {}
}
