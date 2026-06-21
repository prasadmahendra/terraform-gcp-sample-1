output "service_url" {
  value = google_cloud_run_v2_service.run_service.uri
}

output "service_account_email" {
  value = google_service_account.service_account_for_cloud_run.email
}
