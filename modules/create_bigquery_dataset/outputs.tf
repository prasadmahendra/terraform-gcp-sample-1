output "dataset_owner_service_account_email" {
  value = google_service_account.bigquery_service_account.email
}

output "dataset_id" {
  value = google_bigquery_dataset.bigquery_dataset.dataset_id
}