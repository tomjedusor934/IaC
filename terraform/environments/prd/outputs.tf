output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "artifact_registry_url" {
  description = "Artifact Registry URL for docker push/pull"
  value       = module.artifact_registry.repository_url
}

output "cloudsql_instance_connection_name" {
  description = "Cloud SQL connection name"
  value       = module.cloudsql.instance_connection_name
}

output "cloudsql_private_ip" {
  description = "Cloud SQL private IP"
  value       = module.cloudsql.private_ip
}

output "wif_provider" {
  description = "Workload Identity Federation provider"
  value       = module.wif.workload_identity_provider
}

output "wif_service_account_email" {
  description = "GitHub Actions service account email"
  value       = module.wif.service_account_email
}

output "app_service_account_email" {
  description = "App service account email"
  value       = module.iam.app_service_account_email
}
