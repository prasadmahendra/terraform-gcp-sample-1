data "google_secret_manager_secret_version" "datadog_api_key" {
  secret  = "datadog_api_key"
  project = google_project.deployment-central.project_id
}

data "google_secret_manager_secret_version" "datadog_app_key" {
  secret  = "datadog_app_key"
  project = google_project.deployment-central.project_id
}

module "datadog" {
  source                       = "../modules/datadog"
  environment                  = var.environment
  project_id                   = google_project.deployment-central.project_id
  datadog_api_key              = data.google_secret_manager_secret_version.datadog_api_key.secret_data
  datadog_app_key              = data.google_secret_manager_secret_version.datadog_app_key.secret_data
  datadog_endpoint             = var.datadog_endpoint
  datadog_logs_intake_endpoint = var.datadog_logs_intake_endpoint
}

# BigQuery access at the project level for Billing
resource "google_project_iam_custom_role" "datadog_integration_bigquery_access_role" {
  role_id = "datadog_integration_bigquery_access_role"
  title   = "Datadog Integration BigQuery Access Role"
  project = var.project_id
  permissions = [
    "bigquery.jobs.create",
    "bigquery.transfers.get",
    "bigquery.transfers.update",
    ]
}

resource "google_project_iam_member" "project_iam_member_bigquery_job_user" {
  project = var.project_id
  role    = google_project_iam_custom_role.datadog_integration_bigquery_access_role.id
  member  = "serviceAccount:${module.datadog.datadog_integration_service_account_email}"
}

# BigQuery dataset access for Billing
resource "google_project_iam_custom_role" "datadog_integration_bigquery_dataset_access_role" {
  role_id = "datadog_integration_bigquery_dataset_access_role"
  title   = "Datadog Integration BigQuery Dataset Access Role"
  project = var.project_id
  permissions = [
    "bigquery.datasets.get",
    "bigquery.tables.create",
    "bigquery.tables.delete",
    "bigquery.tables.export",
    "bigquery.tables.get",
    "bigquery.tables.getData",
    "bigquery.tables.list",
    "bigquery.tables.update",
    "bigquery.tables.updateData"
  ]
}

# BigQuery Data Viewer at the resource level necessary to access your data to be ingested
resource "google_project_iam_member" "project_iam_member_bigquery_data_viewer" {
  project = var.project_id
  role    = google_project_iam_custom_role.datadog_integration_bigquery_dataset_access_role.id
  member  = "serviceAccount:${module.datadog.datadog_integration_service_account_email}"
  condition {
    title       = "Allow big-query dataset access"
    description = "Terraform Managed - Allow big-query access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/datasets/${module.bigquery_datasets_gcp_billing.dataset_id}")
EXPR
  }
}

# Storage Admin on the GCS bucket you're using for ingestion.
resource "google_project_iam_custom_role" "datadog_integration_storage_access_role" {
  role_id = "datadog_integration_storage_access_role"
  title   = "Datadog Integration Storage Access Role"
  project = var.project_id
  permissions = [
    "storage.buckets.get",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list"
  ]
}

resource "google_storage_bucket" "datadog-cloudcosts-billing-data" {
  name                     = "spiffy-datadog-cloudcosts-billing-data-${var.environment}"
  location                 = var.region
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "REGIONAL"
  project                  = var.project_id
}

# Storage Admin on the GCS bucket you're using for ingestion.
resource "google_project_iam_member" "project_iam_member_storage_admin" {
  project = var.project_id
  role    = google_project_iam_custom_role.datadog_integration_storage_access_role.id
  member  = "serviceAccount:${module.datadog.datadog_integration_service_account_email}"
  condition {
    title       = "Allow storage access"
    description = "Terraform Managed - Allow storage access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${google_storage_bucket.datadog-cloudcosts-billing-data.name}")
EXPR
  }
}