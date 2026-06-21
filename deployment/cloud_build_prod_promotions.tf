###################################################################################################################################
###### CAUTION:
#  Terraform resources section below configures a SA that assumed by Circile CI to promote builds to prod. ######
#  Do not give it more permissions than necessary and be careful when modifying it. For example if you give this SA admin access, then Circle CI
#  will have admin access to your GCP project which is a major security risk.
#  Only give it the minimum permissions necessary to promote builds to prod.
#
##################################################################################################################################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger
# Service account for promoting builds to prod
resource "google_service_account" "cloudbuild_service_account_for_promoting_builds_to_prod" {

  count   = 1
  account_id   = "${var.environment}-cloudbuild-promote-sa"
  display_name = "Service Account for ${var.environment} Promote Cloud Build triggers"
  project      = google_project.deployment-project.project_id
}

# SECURITY FIX: Instead of granting project-wide iam.serviceAccountUser (which allows impersonating ANY SA),
# we scope it to specific service accounts that the promote SA needs to act as during deployments.
#
# To add a new service account, add its account_id (without @project.iam.gserviceaccount.com) to this list.
# Example: if your service account is "my-service-sa@project.iam.gserviceaccount.com", add "my-service-sa"
locals {
  # List of service account IDs that the promote SA is allowed to impersonate
  # Add new service accounts here as needed for deployments
  allowed_service_accounts_for_prod_promote = [
    "webapp-admin-sa",           # webapp-admin Cloud Run service
    "shopify-app-sa",            # shopify-app Cloud Run service
    # Add additional service accounts below as needed:
    # "another-service-sa",
  ]
}

# Look up each allowed service account
data "google_service_account" "allowed_for_prod_promote" {
  for_each   = toset(local.allowed_service_accounts_for_prod_promote)
  account_id = each.value
  project    = google_project.deployment-project.project_id
}

# Grant iam.serviceAccountUser ONLY on specific service accounts, not project-wide
resource "google_service_account_iam_member" "promote_sa_can_impersonate" {
  for_each           = data.google_service_account.allowed_for_prod_promote
  service_account_id = each.value.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].email}"
}

resource "google_project_iam_member" "cloudbuild_service_account_for_promoting_builds_to_prod_cloud_run_job_invoker" {
  count   = var.environment == "dev" ? 1 : 0
  project = google_project.deployment-project.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].email}"
}

# Give cloud-build access to write logs
resource "google_project_iam_member" "cloudbuild_service_account_for_promoting_builds_to_prod_logs_writer" {

  count   = 1
  project = google_project.deployment-project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].email}"
}

# Reuse the custom roles defined in cloud_build.tf instead of duplicating them
# This avoids role ID conflicts and keeps permissions in sync

resource "google_project_iam_member" "cloudbuild_service_account_for_promoting_builds_to_prod_cloudrun_invoker" {
  count   = 1
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudrun-deployment-custom-role.id
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].email}"
}

resource "google_project_iam_member" "cloudbuild_service_account_for_promoting_builds_to_prod_gke_clusters_access" {
  count   = 1
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudrun-gke-clusters-custom-role.id
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].email}"
}


