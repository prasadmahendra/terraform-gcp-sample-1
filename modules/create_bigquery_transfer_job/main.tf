resource "random_string" "random_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "google_project_iam_custom_role" "big_query_transfer_jobs_custom_role" {
  role_id     = "spiffy.roleForBigQueryTransferJobs_${random_string.random_suffix.result}"
  project     = var.project_id
  title       = "Role for BQ transfer jobs"
  description = "Terraform Managed - Role for BQ transfer job ${var.job_name}"
  permissions = concat(
    [
      "bigquery.datasets.get",
      "bigquery.tables.get",
      "bigquery.tables.getData",
      "bigquery.tables.getIamPolicy",
      "bigquery.tables.updateData",
      "bigquery.tables.list",
      "bigquery.jobs.create",
      "bigquery.tables.create",
      "bigquery.tables.update"
    ]
  )
}

resource "google_service_account" "bigquery_datatransfer_service_account" {

  account_id   = "bq-transfer-${random_string.random_suffix.result}-sa"
  display_name = "Managed By Terraform - BigQuery Transfer Service Account for ${var.job_name}"
  project      = var.project_id
}

resource "google_project_iam_member" "big_query_transfer_jobs_sa_role_member_1" {
  project = var.project_id
  role    = google_project_iam_custom_role.big_query_transfer_jobs_custom_role.id
  member  = "serviceAccount:${google_service_account.bigquery_datatransfer_service_account.email}"
}

resource "google_project_iam_member" "big_query_transfer_jobs_sa_role_member_2" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.bigquery_datatransfer_service_account.email}"
}

resource "google_project_iam_member" "big_query_transfer_jobs_sa_role_member_3" {
  project = var.project_id
  role    = "roles/bigquerydatatransfer.serviceAgent"
  member  = "serviceAccount:${google_service_account.bigquery_datatransfer_service_account.email}"
}

resource "google_bigquery_data_transfer_config" "bigquery_datatable_for_segment_cdp_streams_user_id_mappings_transfer_config" {

  display_name           = var.job_name
  location               = var.region
  data_source_id         = "scheduled_query"
  schedule               = var.schedule
  service_account_name   = google_service_account.bigquery_datatransfer_service_account.email
  destination_dataset_id = var.destination_dataset_id
  params = {
    destination_table_name_template = var.destination_table_name
    write_disposition               = "WRITE_APPEND"
    query                           = var.query
  }
}
