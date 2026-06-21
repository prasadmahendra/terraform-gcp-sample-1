resource "google_storage_bucket" "amplitude-ingest-offload-bucket" {
  name                     = "spiffy-amplitude-ingest-offload-${var.environment}"
  location                 = var.region_default
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "REGIONAL"
  project                  = var.project_id
}

# service account for amplitude integration
resource "google_service_account" "amplitude_integration_service_account" {
  account_id   = "amplitude-integration-sa"
  display_name = "Managed by Terraform - SA for Amplitude Integration"
  project      = var.project_id
}

# https://amplitude.com/docs/data/source-catalog/bigquery#prerequisites
# BigQuery Job User at the project level.
resource "google_project_iam_member" "project_iam_member_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.amplitude_integration_service_account.email}"
}

# BigQuery Data Viewer at the resource level necessary to access your data to be ingested
resource "google_project_iam_member" "project_iam_member_bigquery_data_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.amplitude_integration_service_account.email}"
  condition {
    title       = "Allow big-query access"
    description = "Terraform Managed - Allow big-query access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/datasets/chats_commerce")
EXPR
  }
}

# Storage Admin on the GCS bucket you're using for ingestion.
resource "google_project_iam_member" "project_iam_member_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.amplitude_integration_service_account.email}"
  condition {
    title       = "Allow storage access"
    description = "Terraform Managed - Allow storage access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${google_storage_bucket.amplitude-ingest-offload-bucket.name}")
EXPR
  }
}