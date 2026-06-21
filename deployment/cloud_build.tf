resource "google_cloudbuild_worker_pool" "cloudbuild_worker_pool_e2" {

  count    = var.environment == "dev" && var.enable_private_build_worker_pool == true ? 1 : 0
  name     = "${var.environment}-cloudbuild-worker-pool-e2"
  location = var.region_default
  project  = google_project.deployment-project.project_id
  worker_config {
    # https://cloud.google.com/build/pricing
    disk_size_gb   = 100
    machine_type   = "e2-standard-32"
    no_external_ip = false # TODO/FIXME: Run a private worker pool and peer with the VPC dev environment
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger
# Service account for building artifacts
resource "google_service_account" "cloudbuild_service_account" {

  count   = 1
  account_id   = "${var.environment}-cloudbuild-sa"
  display_name = "Service Account for ${var.environment} Cloud Build triggers"
  project      = google_project.deployment-project.project_id
}

# SECURITY FIX: Instead of granting project-wide iam.serviceAccountUser (which allows impersonating ANY SA),
# we scope it to specific service accounts that Cloud Build needs to act as during deployments.
#
# To add a new service account, add its account_id (without @project.iam.gserviceaccount.com) to this list.
locals {
  # List of service account IDs that Cloud Build SA is allowed to impersonate
  # Add new service accounts here as needed for deployments
  allowed_service_accounts_for_cloudbuild = [
    "webapp-admin-sa",           # webapp-admin Cloud Run service
    # Add additional service accounts below as needed:
    # "another-service-sa",
  ]
}

# Look up each allowed service account
data "google_service_account" "allowed_for_cloudbuild" {
  for_each   = toset(local.allowed_service_accounts_for_cloudbuild)
  account_id = each.value
  project    = google_project.deployment-project.project_id
}

# Grant iam.serviceAccountUser ONLY on specific service accounts, not project-wide
resource "google_service_account_iam_member" "cloudbuild_sa_can_impersonate" {
  for_each           = data.google_service_account.allowed_for_cloudbuild
  service_account_id = each.value.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"
}

resource "google_project_iam_member" "cloudbuild_service_account_cloud_run_job_invoker" {
  count   = var.environment == "dev" ? 1 : 0
  project = google_project.deployment-project.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"
}

# Give cloud-build access to write logs
resource "google_project_iam_member" "cloudbuild_service_account_logs_writer" {

  count   = 1
  project = google_project.deployment-project.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"
}

# Give cloud build access to read from secrets manager
resource "google_project_iam_member" "cloudbuild_service_account_secrets_manager_perms" {

  count   = 1
  project = google_project.deployment-project.project_id
  # https://cloud.google.com/secret-manager/docs/access-control
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"
}

# Give cloud-build access to cloud-run to trigger deployments
resource "google_project_iam_custom_role" "cloudrun-deployment-custom-role" {
  role_id     = "spiffy.cicdDeploymentTriggerRole"
  project     = var.project_id
  title       = "CloudRun Deployment Trigger Role"
  description = "CloudRun Deployment Trigger Role"
  permissions = [
    "run.jobs.list",
    "run.jobs.get",
    "run.jobs.run",
    "run.jobs.runWithOverrides",
    "run.executions.get",
    "run.executions.list",
    "run.services.get",
    "run.services.update",
    "run.operations.get",
    "compute.projects.get",
    "compute.instances.get",
    "artifactregistry.repositories.get",
    "artifactregistry.repositories.uploadArtifacts",
    "artifactregistry.repositories.downloadArtifacts",
  ]
}


resource "google_project_iam_member" "cloudbuild_service_account_cloudrun_invoker" {

  count   = 1
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudrun-deployment-custom-role.id
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"
}

# Give cloud-build access to storage bucket containing deployment configs
resource "google_project_iam_custom_role" "cloudrun-configs-bucket-readonly-custom-role" {
  role_id     = "spiffy.cicdDeploymentStorageBucketsReadOnlyRole"
  project     = var.project_id
  title       = "CloudRun Deployment Trigger Storage Buckets RO Role"
  description = "CloudRun Deployment Trigger Storage Buckets RO Role"
  permissions = ["storage.objects.get"]
}

# Give cloud-build access to storage bucket containing deployment configs
resource "google_project_iam_custom_role" "cloudrun-artifact-bucket-readwrite-custom-role" {
  role_id     = "spiffy.cicdDeploymentArtifactBucketsReadWriteRole"
  project     = var.project_id
  title       = "CloudRun Deployment Artifact Buckets RW Role"
  description = "CloudRun Deployment Artifact Buckets RW Role"
  permissions = [
    "storage.objects.create",
    "storage.objects.list",
    "storage.objects.update",
    "storage.folders.get",
    "storage.folders.list",
    "storage.objects.delete"
  ]
}

# Give cloud-build access to GKE configs
resource "google_project_iam_custom_role" "cloudrun-gke-clusters-custom-role" {
  role_id     = "spiffy.cicdDeploymentGkeClustersRole"
  project     = var.project_id
  title       = "CloudRun Deployment Trigger GKE Role"
  description = "CloudRun Deployment Trigger GKE Role"
  permissions = [
    "container.clusters.get",
    "container.deployments.get",
    "container.deployments.update",
    "container.deployments.list"
  ]
}

resource "google_project_iam_member" "cloudbuild_service_account_gke_clusters_access" {

  count   = 1
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudrun-gke-clusters-custom-role.id
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"
}

resource "google_project_iam_member" "cloudbuild_service_account_storagebuckets_readonly_access" {

  count   = 1
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudrun-configs-bucket-readonly-custom-role.id
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"

  # Tighten up the permissions here to only give access to configs bucket!
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
  condition {
    title       = "CloudBuild storage access limited to configs bucket"
    description = "CloudBuild storage access limited to configs bucket"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.spiffy-configs.name}/\")"
  }
}

resource "google_project_iam_member" "cloudbuild_service_account_storagebuckets_readwrite_access" {

  count   = 1
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudrun-artifact-bucket-readwrite-custom-role.id
  member  = "serviceAccount:${google_service_account.cloudbuild_service_account[0].email}"

  # Tighten up the permissions here to only give access to artifacts bucket!
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
  condition {
    title       = "CloudBuild storage access limited to artifacts buckets"
    description = "CloudBuild storage access limited to artifacts bucket"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.spiffy-deployment-artifacts.name}\")"
  }
}

# https://cloud.google.com/build/docs/configuring-notifications/configure-slack
# https://registry.terraform.io/modules/simplifi/cloud-build-slack-notifier/google/latest
module "cloud-build-slack-notifier" {

  count                            = var.environment == "dev" ? 1 : 0
  source                           = "simplifi/cloud-build-slack-notifier/google"
  version                          = "0.4.0"
  name                             = "spiffy-ai-slack-${var.environment}"
  project_id                       = google_project.deployment-project.project_id
  slack_webhook_url_secret_id      = "cloud-build-slack-webhook-url-secret"
  slack_webhook_url_secret_project = google_project.deployment-project.project_id
  cloud_build_event_filter         = "build.substitutions['BRANCH_NAME'] == 'main' && build.status in [Build.Status.SUCCESS, Build.Status.FAILURE, Build.Status.TIMEOUT]"
  # Build.XXX is type.Build proto from here:
  # https://pkg.go.dev/cloud.google.com/go/cloudbuild/apiv1/v2/cloudbuildpb
  # https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds (for Substitutions)
  override_slack_template_json     = <<JSON
[
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "{{.Build.Substitutions.REPO_NAME}} ({{.Build.Substitutions.BRANCH_NAME}})\nProject ID: {{.Build.ProjectId}}\nBuild ID: {{.Build.Id}}\nStatus: {{.Build.Status}}"
      }
    },
    {
      "type": "divider"
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "View Build Logs"
      },
      "accessory": {
        "type": "button",
        "text": {
          "type": "plain_text",
          "text": "Logs"
        },
        "value": "click_me_123",
        "url": "{{.Build.LogUrl}}",
        "action_id": "button-action"
      }
    }
  ]
    JSON
}

data "google_secret_manager_secret_version" "slack-webhook-url-secret" {

  count   = var.environment == "dev" ? 1 : 0
  secret  = "cloud-build-slack-webhook-url-secret"
  project = google_project.deployment-project.project_id
}