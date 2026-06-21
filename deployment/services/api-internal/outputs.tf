output "google_service_account_email" {
  description = "The service account email"
  value       = google_service_account.service_account.email
}
