# Workload Identity Federation for GitHub Actions
#
# Allows the terraform plan workflow in spiffy-ai/terraform to authenticate
# to GCP using GitHub OIDC tokens — no static service account keys needed.
#
# After applying, set these GitHub repository secrets:
#   WIF_PROVIDER_CENTRAL  = output.github_actions_wif_provider
#   SA_EMAIL_CENTRAL      = output.github_actions_tf_plan_sa_email

# These resources were bootstrapped via gcloud before first apply.
# Import blocks bring them under Terraform management on first apply.
import {
  id = "projects/${var.project_id}/locations/global/workloadIdentityPools/github-actions"
  to = google_iam_workload_identity_pool.github_actions
}

import {
  id = "projects/${var.project_id}/locations/global/workloadIdentityPools/github-actions/providers/github-actions"
  to = google_iam_workload_identity_pool_provider.github_actions
}

import {
  id = "projects/${var.project_id}/serviceAccounts/github-actions-tf-plan@${var.project_id}.iam.gserviceaccount.com"
  to = google_service_account.github_actions_tf_plan
}

resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "WIF pool for GitHub Actions (terraform plan CI)"
  project                   = google_project.deployment-central.project_id
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions OIDC"
  project                            = google_project.deployment-central.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Restrict to the terraform repo only — prevents other repos from using this pool
  attribute_condition = "attribute.repository == \"spiffy-ai/terraform\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions_tf_plan" {
  account_id   = "github-actions-tf-plan"
  display_name = "GitHub Actions Terraform Plan"
  description  = "Keyless SA for terraform plan CI (WIF via GitHub Actions OIDC)"
  project      = google_project.deployment-central.project_id
}

# Allow GitHub Actions workflow tokens from spiffy-ai/terraform to impersonate this SA
resource "google_service_account_iam_member" "github_actions_tf_plan_wif" {
  service_account_id = google_service_account.github_actions_tf_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/spiffy-ai/terraform"
}

# Read-only access to all project resources — needed for terraform plan
resource "google_project_iam_member" "github_actions_tf_plan_viewer" {
  project = google_project.deployment-central.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read secrets from Secret Manager (central reads datadog/elasticsearch keys directly
# via google_secret_manager_secret_version data sources during plan)
resource "google_project_iam_member" "github_actions_tf_plan_secret_accessor" {
  project = google_project.deployment-central.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read IAM policies on resources (*.getIamPolicy) — needed for Terraform plan.
resource "google_project_iam_member" "github_actions_tf_plan_security_reviewer" {
  project = google_project.deployment-central.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Allow API quota to be billed against inner-tokenizer.
resource "google_project_iam_member" "github_actions_tf_plan_service_usage" {
  project = var.project_id_for_quotas
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# central/ manages org-level folder resources — the SA needs resourcemanager.folders.get
# on the org folder hierarchy. Requires org/folder admin to grant; tracked separately.
# resource "google_organization_iam_member" "github_actions_tf_plan_folder_viewer" {
#   org_id = var.org_id
#   role   = "roles/resourcemanager.folderViewer"
#   member = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
# }

# Read billing account info (data "google_billing_account").
# Requires billing admin to grant; tracked separately.
# resource "google_billing_account_iam_member" "github_actions_tf_plan_billing_viewer" {
#   billing_account_id = "015900-535DF2-C09343"
#   role               = "roles/billing.viewer"
#   member             = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
# }

# Read remote state from deployment (dev + prod) buckets.
# central plan reads terraform_remote_state for dev and prod environments.
resource "google_storage_bucket_iam_member" "github_actions_tf_plan_remote_state" {
  for_each = toset(["spiffy-tfstate-dev", "spiffy-tfstate-prod"])
  bucket   = each.key
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read/write terraform state lock — objectUser allows get/create/delete on objects
# without granting full objectAdmin (no setIamPolicy, no overwrite-all).
resource "google_storage_bucket_iam_member" "github_actions_tf_plan_state" {
  bucket = "spiffy-tfstate-central"
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read Cloud Identity groups (google_cloud_identity_group resources) during terraform plan.
# central/ manages workspace groups; without this the plan fails with Error(2028) 403.
resource "google_organization_iam_member" "github_actions_tf_plan_cloudidentity_reader" {
  org_id = var.org_id
  role   = "roles/cloudidentity.groups.reader"
  member = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}
