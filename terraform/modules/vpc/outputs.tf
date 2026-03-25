output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = google_compute_network.main.self_link
}

output "gke_subnet_id" {
  description = "GKE subnet ID"
  value       = google_compute_subnetwork.gke.id
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = google_compute_subnetwork.gke.name
}

output "gke_subnet_self_link" {
  description = "GKE subnet self link"
  value       = google_compute_subnetwork.gke.self_link
}

output "private_service_access_connection" {
  description = "Private service access connection"
  value       = google_service_networking_connection.private_service_access
}
