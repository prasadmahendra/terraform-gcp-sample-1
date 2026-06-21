resource "google_project_iam_custom_role" "deployment_engineers_role_for_gcs_access_for_prod" {
  role_id = "spiffy.groupDeploymentEngineersRoleGCSAccessProd"
  project = var.project_id
  title   = "Deployment Engineers - GCS Access [PROD]"
  description = "Terraform Managed - Deployment Engineers - GCS Access [PROD]"
  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
  ]
}

resource "google_project_iam_member" "project_iam_binding_for_deployment_engineers_gcs_access_for_prod" {
  project = var.project_id
  role    = google_project_iam_custom_role.deployment_engineers_role_for_gcs_access_for_prod.id
  member  = local.gsuite_deployment_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_gcs_ro_access_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/storage.objectViewer"
  member = local.gsuite_deployment_engineers_group_id

  condition {
    title      = "Allow GCS RO access for Deployment Engineers [PROD]"
    description = "Terraform Managed - Allow GCS RO access for Deployment Engineers [PROD]"
    # https://cloud.google.com/iam/docs/conditions-overview
    expression = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-chat-frontend-prod")
EXPR
  }
}

# view/list access to all buckets
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_gcs_ro_access_for_all_buckets_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/storage.objectViewer"
  member = local.gsuite_deployment_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_gcs_rw_access_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/storage.objectCreator"
  member = local.gsuite_deployment_engineers_group_id

  condition {
    title      = "Allow GCS RW access for Deployment Engineers [PROD]"
    description = "Terraform Managed - Allow GCS RW access for Deployment Engineers [PROD]"
    # https://cloud.google.com/iam/docs/conditions-overview
    expression = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-chat-frontend-prod")
EXPR
  }
}

# bucket spiffy-llm-inference-service-prod write access
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_gcs_rw_access_for_llm_inference_service_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/storage.objectUser"
  member = local.gsuite_deployment_engineers_group_id

  condition {
    title      = "Allow GCS RW access for Deployment Engineers [LLM Inference Service PROD]"
    description = "Terraform Managed - Allow GCS RW access for Deployment Engineers [LLM Inference Service PROD]"
    # https://cloud.google.com/iam/docs/conditions-overview
    expression = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-llm-inference-service-prod")
EXPR
  }
}

# roles/cloudbuild.builds.approver
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_cloudbuild_builds_approver_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/cloudbuild.builds.approver"
  member = local.gsuite_deployment_engineers_group_id
}

# roles/artifactregistry.reader
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_artifact_registry_reader_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/artifactregistry.reader"
  member = local.gsuite_deployment_engineers_group_id
}

# custom role with cloudbuild.builds.create
resource "google_organization_iam_custom_role" "org_role_for_deployment_engineers_cloudbuild_builds_create_for_prod" {
  role_id = "spiffy.deploymentEngineersRoleCloudBuildProd"
  org_id  = var.org_id
  title   = "Role for Deployment Engineers - Cloudbuild Builds Create [PROD]"
  description = "Terraform Managed - Role for Deployment Engineers - Cloudbuild Builds Create [PROD]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    # Required for triggers run: https://cloud.google.com/build/docs/api/reference/rest/v1/projects.triggers/run
    "cloudbuild.builds.create",
    "cloudbuild.builds.update",
    "cloudbuild.builds.get",
    "cloudbuild.builds.list"
  ]
}

resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_cloudbuild_builds_create_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = google_organization_iam_custom_role.org_role_for_deployment_engineers_cloudbuild_builds_create_for_prod.id
  member = local.gsuite_deployment_engineers_group_id
}

# roles/cloudbuild.workerPoolUser
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_cloudbuild_worker_pool_user_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/cloudbuild.workerPoolUser"
  member = local.gsuite_deployment_engineers_group_id
}

# users need impersonation permission on the trigger service account specified:
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_service_account_token_creator_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/iam.serviceAccountTokenCreator"
  member = local.gsuite_deployment_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_service_account_user_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/iam.serviceAccountUser"
  member = local.gsuite_deployment_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_storage_transfer_user_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/storagetransfer.user"
  member = local.gsuite_deployment_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_service_usage_consumer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/serviceusage.serviceUsageConsumer"
  member = local.gsuite_deployment_engineers_group_id
}

# cloud run/cloud job viewer role
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_cloud_run_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/run.viewer"
  member = local.gsuite_deployment_engineers_group_id
}

# roles/run.sourceViewer
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_run_source_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/run.sourceViewer"
  member = local.gsuite_deployment_engineers_group_id
}

# roles/logging.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_logging_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/logging.viewer"
  member = local.gsuite_deployment_engineers_group_id
}

# roles/monitoring.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_deployment_engineers_monitoring_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/monitoring.viewer"
  member = local.gsuite_deployment_engineers_group_id
}
