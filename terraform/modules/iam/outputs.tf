output "app_service_account_email" {
  description = "Email of the application service account"
  value       = google_service_account.app.email
}

output "app_service_account_name" {
  description = "Full resource name of the application service account"
  value       = google_service_account.app.name
}
