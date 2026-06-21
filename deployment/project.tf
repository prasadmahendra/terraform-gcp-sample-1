locals {
  project_folder_id = var.environment == "prod" ? data.terraform_remote_state.central.outputs.prod_env_project_folder_id : data.terraform_remote_state.central.outputs.dev_env_project_folder_id
}

# Billing account ID used directly to avoid requiring roles/billing.viewer
# (data.google_billing_account lookup needs that permission; the SA only has viewer).
locals {
  billing_account_id = var.billing_account_id
}

resource "google_project" "deployment-project" {
  name            = var.project_name
  project_id = var.project_id
  # org_id          = var.org_id
  folder_id       = local.project_folder_id
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
    "sql-component.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "redis.googleapis.com",
    "billingbudgets.googleapis.com",
    "container.googleapis.com",
    "containerregistry.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudkms.googleapis.com",
    "mesh.googleapis.com",
    "anthos.googleapis.com",
    "composer.googleapis.com",
    "logging.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "monitoring.googleapis.com",
    "sts.googleapis.com",
    "autoscaling.googleapis.com",
    "servicedirectory.googleapis.com",
    "trafficdirector.googleapis.com",
    "networkservices.googleapis.com",
    "multiclusteringress.googleapis.com",
    "gkehub.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "clouddeploy.googleapis.com",
    "file.googleapis.com",
    "storagetransfer.googleapis.com",
    "firestore.googleapis.com",
    "apigateway.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicecontrol.googleapis.com",
    "datastream.googleapis.com",
    "endpoints.googleapis.com",
    "containerfilesystem.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
    "tpu.googleapis.com",
    "dataflow.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "bigtable.googleapis.com",
    "bigtableadmin.googleapis.com",
    "containerscanning.googleapis.com", # Enables Artifact Registry Vulnerability scanning
    "containersecurity.googleapis.com", # Container Security API - Security insights into Google Kubernetes Engine clusters
    "ids.googleapis.com",
    "cloudidentity.googleapis.com",
    "cloudscheduler.googleapis.com",
    "certificatemanager.googleapis.com",
    "aiplatform.googleapis.com",
    "iap.googleapis.com"
  ]
}

resource "google_project_service" "all" {
  for_each           = toset(var.gcp_service_list)
  project            = google_project.deployment-project.project_id
  service            = each.key
  disable_on_destroy = false
}