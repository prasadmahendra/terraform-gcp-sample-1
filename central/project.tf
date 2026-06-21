# Billing account ID used directly to avoid requiring roles/billing.viewer
locals {
  billing_account_id = var.billing_account_id
}

resource "google_project" "deployment-central" {
  name            = var.project_name
  project_id      = var.project_id
  #org_id          = var.org_id
  folder_id       = google_folder.spiffy-org-eng-gcp-env-central-folder.id
  billing_account = local.billing_account_id
}

variable "gcp_service_list" {
  description = "The list of apis necessary for the project"
  type        = list(string)
  default     = [
    "compute.googleapis.com",
    "cloudapis.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "sourcerepo.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudidentity.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "sqladmin.googleapis.com",
    "containeranalysis.googleapis.com",
    "firestore.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "storage-api.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com"
  ]
}

resource "google_project_service" "all" {
  for_each           = toset(var.gcp_service_list)
  project            = google_project.deployment-central.project_id
  service            = each.key
  disable_on_destroy = false
}


# https://github.com/terraform-google-modules/terraform-example-foundation
