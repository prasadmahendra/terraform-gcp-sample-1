locals {
  gcc_cluster_name = "gcc-default"
}

resource "google_storage_bucket" "composer-environment-default-bucket" {
  name                     = "spiffy-${local.gcc_cluster_name}-${var.environment}"
  location                 = var.region_default
  force_destroy            = true
  public_access_prevention = "enforced"
  storage_class = "STANDARD"  # must be STANDARD for Composer to work
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

module "composer-environment-default" {

  count = contains(["dev", "prod"], var.environment) && var.composer_cluster_enabled ? 1 : 0 # Only in dev or prod
  source               = "../modules/create_composer_environment"
  environment          = var.environment
  cluster_name         = local.gcc_cluster_name
  environment_size = var.environment == "dev" ? "ENVIRONMENT_SIZE_SMALL" : "ENVIRONMENT_SIZE_MEDIUM" # or ENVIRONMENT_SIZE_LARGE
  project_id           = google_project.deployment-project.project_id
  region               = var.region_default
  service_account_name = google_service_account.composer-environment-default-sa[0].name
  subnet_id            = google_compute_subnetwork.deployment-subnet-app.id
  vpc_id               = google_compute_network.vpc-deployment.id
  bucket_name          = google_storage_bucket.composer-environment-default-bucket.name
}

resource "google_service_account" "composer-environment-default-sa" {

  count = contains(["dev", "prod"], var.environment) && var.composer_cluster_enabled ? 1 : 0 # Only in dev or prod
  account_id   = "composer-env-default-sa"
  display_name = "Composer Environment Service Account"
}

resource "google_project_iam_member" "composer-worker" {

  count = contains(["dev", "prod"], var.environment) && var.composer_cluster_enabled ? 1 : 0 # Only in dev or prod
  project = google_project.deployment-project.id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer-environment-default-sa[0].email}"
}

resource "google_service_account_iam_member" "custom_service_account" {

  count = contains(["dev", "prod"], var.environment) && var.composer_cluster_enabled ? 1 : 0 # Only in dev or prod
  service_account_id = google_service_account.composer-environment-default-sa[0].id
  role               = "roles/composer.ServiceAgentV2Ext"
  member             = "serviceAccount:service-${google_project.deployment-project.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}
