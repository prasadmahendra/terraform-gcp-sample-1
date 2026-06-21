# Workload Identity Federation for GitHub Actions
#
# Allows the terraform plan workflow in spiffy-ai/terraform to authenticate
# to GCP using GitHub OIDC tokens — no static service account keys needed.
#
# After applying, set these GitHub repository secrets:
#   WIF_PROVIDER_DEV   = output.github_actions_wif_provider  (from dev apply)
#   SA_EMAIL_DEV       = output.github_actions_tf_plan_sa_email  (from dev apply)
#   WIF_PROVIDER_PROD  = output.github_actions_wif_provider  (from prod apply)
#   SA_EMAIL_PROD      = output.github_actions_tf_plan_sa_email  (from prod apply)

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
  project                   = google_project.deployment-project.project_id
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions OIDC"
  project                            = google_project.deployment-project.project_id

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
  project      = google_project.deployment-project.project_id
}

# Allow GitHub Actions workflow tokens from spiffy-ai/terraform to impersonate this SA
resource "google_service_account_iam_member" "github_actions_tf_plan_wif" {
  service_account_id = google_service_account.github_actions_tf_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/spiffy-ai/terraform"
}

# Read-only access to all project resources — needed for terraform plan
resource "google_project_iam_member" "github_actions_tf_plan_viewer" {
  project = google_project.deployment-project.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read secrets from Secret Manager (datadog keys, elasticsearch key)
resource "google_project_iam_member" "github_actions_tf_plan_secret_accessor" {
  project = google_project.deployment-project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read GKE cluster credentials from the GCP control plane.
resource "google_project_iam_member" "github_actions_tf_plan_container_viewer" {
  project = google_project.deployment-project.project_id
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read Kubernetes API objects (secrets, pods, etc.) inside GKE clusters.
# Required for helm_release and data.kubernetes_secret resources during plan/apply.
# roles/container.clusterViewer only grants GCP control-plane access; it does NOT
# allow K8s API calls. roles/container.developer is the minimum GCP predefined role
# that provides K8s API access. This SA is scoped solely to CI/CD use (no humans).
resource "google_project_iam_member" "github_actions_tf_plan_container_developer" {
  project = google_project.deployment-project.project_id
  role    = "roles/container.developer" # NOSONAR - minimum role for K8s API access; SA is CI/CD-only, no human principals
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read BigQuery table/dataset metadata — roles/viewer does NOT include bigquery.tables.get,
# which is required for Terraform to refresh BigQuery table resources during plan.
resource "google_project_iam_member" "github_actions_tf_plan_bq_viewer" {
  project = google_project.deployment-project.project_id
  role    = "roles/bigquery.metadataViewer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read Cloud Storage bucket metadata (storage.buckets.get) — required for Terraform to
# refresh google_storage_bucket resources when planning with -refresh=true. roles/viewer
# grants storage.buckets.list but NOT storage.buckets.get, and the legacy bucket roles
# (roles/storage.legacyBucketReader) are only grantable on buckets, not at project scope.
# A minimal custom role is the least-privilege way to give the CI plan SA project-wide
# storage.buckets.get. Surfaced as a 403 on spiffy-chat-frontend-prod during the first
# refresh=true run. Bucket getIamPolicy is already covered by roles/iam.securityReviewer.
resource "google_project_iam_custom_role" "tf_plan_storage_bucket_reader" {
  role_id     = "tfPlanStorageBucketReader"
  project     = google_project.deployment-project.project_id
  title       = "Terraform Plan Storage Bucket Reader"
  description = "storage.buckets.get so the CI plan SA can refresh google_storage_bucket resources"
  permissions = ["storage.buckets.get"]
}

resource "google_project_iam_member" "github_actions_tf_plan_storage_bucket_reader" {
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.tf_plan_storage_bucket_reader.name
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read IAM policies on resources (*.getIamPolicy) — needed for Terraform to plan
# google_project_iam_member, pubsub topic IAM bindings, etc.
resource "google_project_iam_member" "github_actions_tf_plan_security_reviewer" {
  project = google_project.deployment-project.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# ── Apply-time elevated permissions ──────────────────────────────────────────
#
# The SA is used for BOTH plan and apply (same WIF principal in CCI context).
# Apply operations require write access to IAM, WIF providers, and SAs.
# These three roles were bootstrapped manually and are imported here so
# Terraform tracks them. Without them, applies fail with 403 on any resource
# that modifies IAM policies (google_project_iam_member, google_service_account_
# iam_member, google_iam_workload_identity_pool_provider).

import {
  id = "${google_project.deployment-project.project_id} roles/resourcemanager.projectIamAdmin serviceAccount:${google_service_account.github_actions_tf_plan.email}"
  to = google_project_iam_member.github_actions_tf_plan_project_iam_admin
}

# Manage project-level IAM bindings (e.g. google_project_iam_member resources).
resource "google_project_iam_member" "github_actions_tf_plan_project_iam_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/resourcemanager.projectIamAdmin" # NOSONAR - required for Terraform apply to manage project IAM bindings; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

import {
  id = "${google_project.deployment-project.project_id} roles/iam.workloadIdentityPoolAdmin serviceAccount:${google_service_account.github_actions_tf_plan.email}"
  to = google_project_iam_member.github_actions_tf_plan_wif_admin
}

# Update WIF pool providers (e.g. google_iam_workload_identity_pool_provider).
resource "google_project_iam_member" "github_actions_tf_plan_wif_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin" # NOSONAR - required for Terraform to manage WIF pool providers; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

import {
  id = "${google_project.deployment-project.project_id} roles/iam.serviceAccountAdmin serviceAccount:${google_service_account.github_actions_tf_plan.email}"
  to = google_project_iam_member.github_actions_tf_plan_sa_admin
}

# Set IAM policies on service accounts (e.g. google_service_account_iam_member).
resource "google_project_iam_member" "github_actions_tf_plan_sa_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/iam.serviceAccountAdmin" # NOSONAR - required for Terraform to set IAM policies on service accounts; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Manage custom IAM roles (create/update/delete google_project_iam_custom_role).
import {
  id = "${google_project.deployment-project.project_id} roles/iam.roleAdmin serviceAccount:${google_service_account.github_actions_tf_plan.email}"
  to = google_project_iam_member.github_actions_tf_plan_role_admin
}

resource "google_project_iam_member" "github_actions_tf_plan_role_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/iam.roleAdmin" # NOSONAR - required for Terraform to manage custom IAM roles; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Manage DNS record sets (google_dns_record_set create/update/delete).
import {
  id = "${google_project.deployment-project.project_id} roles/dns.admin serviceAccount:${google_service_account.github_actions_tf_plan.email}"
  to = google_project_iam_member.github_actions_tf_plan_dns_admin
}

resource "google_project_iam_member" "github_actions_tf_plan_dns_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/dns.admin" # NOSONAR - required for Terraform to manage DNS records; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Manage compute global addresses (google_compute_global_address create/delete).
import {
  id = "${google_project.deployment-project.project_id} roles/compute.networkAdmin serviceAccount:${google_service_account.github_actions_tf_plan.email}"
  to = google_project_iam_member.github_actions_tf_plan_compute_network_admin
}

resource "google_project_iam_member" "github_actions_tf_plan_compute_network_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/compute.networkAdmin" # NOSONAR - required for Terraform to manage compute global addresses; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Allow API quota to be billed against inner-tokenizer (project_id_for_quotas).
# billing_project = var.project_id_for_quotas in versions.tf requires this role
# on that project, otherwise all GCP API calls return 403 USER_PROJECT_DENIED.
resource "google_project_iam_member" "github_actions_tf_plan_service_usage" {
  project = var.project_id_for_quotas
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read/write terraform state lock for THIS environment's bucket.
# objectUser allows get/create/delete on objects without granting full objectAdmin.
resource "google_storage_bucket_iam_member" "github_actions_tf_plan_state" {
  bucket = "spiffy-tfstate-${var.environment}"
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Read remote state from OTHER environments' buckets.
# Each plan reads all three terraform_remote_state data sources (dev, prod, central).
# dev SA needs prod+central; prod SA needs dev+central — handled by the conditional below.
locals {
  cross_env_state_buckets = var.environment == "dev" ? ["spiffy-tfstate-prod", "spiffy-tfstate-central"] : ["spiffy-tfstate-dev", "spiffy-tfstate-central"]
}

resource "google_storage_bucket_iam_member" "github_actions_tf_plan_remote_state" {
  for_each = toset(local.cross_env_state_buckets)
  bucket   = each.key
  role     = "roles/storage.objectViewer"
  member   = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Manage Cloud Armor security policies (compute.securityPolicies.update).
# Required for Terraform to update the public-edge-compute-security-policy resource.
resource "google_project_iam_member" "github_actions_tf_plan_compute_security_admin" {
  project = google_project.deployment-project.project_id
  role    = "roles/compute.securityAdmin" # NOSONAR - required for Terraform to manage Cloud Armor policies; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Create/manage Pub/Sub subscriptions (pubsub.subscriptions.create).
# Required for Terraform to create dead-letter and event-processor subscriptions.
resource "google_project_iam_member" "github_actions_tf_plan_pubsub_editor" {
  project = google_project.deployment-project.project_id
  role    = "roles/pubsub.editor" # NOSONAR - required for Terraform to manage Pub/Sub subscriptions; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Create/update Cloud Monitoring alert policies (monitoring.alertPolicies.update).
# Required for Terraform to manage google_monitoring_alert_policy resources.
resource "google_project_iam_member" "github_actions_tf_plan_monitoring_editor" {
  project = google_project.deployment-project.project_id
  role    = "roles/monitoring.editor" # NOSONAR - required for Terraform to manage Cloud Monitoring alert policies; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}

# Create/manage BigQuery datasets and tables (bigquery.datasets.create,
# bigquery.tables.create). roles/bigquery.metadataViewer above is read-only and
# only covers plan-time refresh; apply needs write access to create the analytics
# dataset + events table (bigquery_analytics_dataset.tf). dataEditor is a superset
# of the metadata reads metadataViewer already grants.
resource "google_project_iam_member" "github_actions_tf_plan_bq_data_editor" {
  project = google_project.deployment-project.project_id
  role    = "roles/bigquery.dataEditor" # NOSONAR - required for Terraform to create BigQuery datasets/tables; SA is CI/CD-only
  member  = "serviceAccount:${google_service_account.github_actions_tf_plan.email}"
}
