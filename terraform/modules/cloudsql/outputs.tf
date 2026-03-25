output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name (project:region:instance)"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  description = "Cloud SQL private IP"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.app.name
}

output "database_user" {
  description = "Database username"
  value       = google_sql_user.app.name
}

output "database_password_secret_id" {
  description = "Secret Manager secret ID for the database password"
  value       = google_secret_manager_secret.db_password.secret_id
}
