module "bigquery_datasets_gcp_billing" {
  source                = "../modules/create_bigquery_dataset"
  project_id            = var.project_id
  dataset_id            = "gcp_spiffy_billing"
  friendly_name         = "GCP Spiffy Billing"
  description           = "GCP billing detailed export"
  environment           = var.environment
  region                = var.region
  is_case_insensitive   = true
  storage_billing_model = "PHYSICAL"
}

