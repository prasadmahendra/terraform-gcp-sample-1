resource "google_service_account" "bigquery_service_account" {
  project     = var.project_id
  account_id  = "${replace(var.dataset_id, "_", "-")}-bq-${lower(random_string.random_suffix.result)}-sa"
  description = "Managed By Terraform - BigQuery service account for ${var.dataset_id}"
}

resource "random_string" "random_suffix" {
  length  = 4
  special = false
}

resource "google_project_iam_custom_role" "bigquery_service_account_custom_role" {
  role_id     = "spiffy.bigQueryServiceAccountRole_${random_string.random_suffix.result}"
  project     = var.project_id
  title       = "BigQuery Service Account Role for ${var.dataset_id}"
  description = "Terraform Managed - BigQuery Service Account Role for ${var.dataset_id}"
  permissions = [
    "bigquery.tables.create",
    "bigquery.connections.delegate"
  ]
}

resource "google_project_iam_member" "bigquery_service_account_custom_role_member" {
  project = var.project_id
  role    = google_project_iam_custom_role.bigquery_service_account_custom_role.id
  member  = "serviceAccount:${google_service_account.bigquery_service_account.email}"
}

# resource "google_project_iam_member" "bigquery_service_account_admin_role_member" {
#   role    = "roles/bigquery.admin"
#   project = var.project_id
#   member  = "serviceAccount:${google_service_account.bigquery_service_account.email}"
# }

resource "google_bigquery_dataset" "bigquery_dataset" {
  depends_on = [
    google_project_iam_member.bigquery_service_account_custom_role_member
  ]
  project                         = var.project_id
  dataset_id                      = var.dataset_id
  friendly_name                   = var.friendly_name
  default_partition_expiration_ms = var.default_partition_expiration_ms
  default_table_expiration_ms     = var.default_table_expiration_ms
  description                     = var.description
  location                        = var.region
  max_time_travel_hours           = var.max_time_travel_hours
  is_case_insensitive             = var.is_case_insensitive
  storage_billing_model           = var.storage_billing_model

  access {
    role          = "OWNER"
    user_by_email = "billing-export-bigquery@system.gserviceaccount.com"
  }
  access {
    role          = "OWNER"
    user_by_email = google_service_account.bigquery_service_account.email
  }

  labels = {
    env = var.environment
  }
}


