locals {
  ai_platform_service_account_email = "service-${google_project.deployment-project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

resource "google_artifact_registry_repository" "artifact_registry_docker" {

  count         = var.environment == "prod" ? 1 : 0
  project       = google_project.deployment-project.project_id
  location      = var.artifact_registry_docker_region
  repository_id = var.org_name
  description   = "${var.org_name} (${var.environment}) docker registry"
  format        = "DOCKER"

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "keep-tagged-release"
    action = "KEEP"
    condition {
      tag_state = "TAGGED"
      tag_prefixes = ["latest", "prod"]
    }
  }
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 50
    }
  }
  cleanup_policies {
    id     = "delete-older-than-15-days"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "1296000s"
    }
  }
  cleanup_policies {
    id     = "delete-older-than-2-years"
    action = "DELETE"
    condition {
      tag_state  = "TAGGED"
      older_than = "63072000s"
    }
  }
}

#
# Registry access control
# https://cloud.google.com/artifact-registry/docs/access-control

# Allow cloud-build service acccount in DEV to upload artifacts
resource "google_project_iam_custom_role" "cloudbuild-artifacts-registry-custom-role" {

  count       = var.environment == "prod" ? 1 : 0
  role_id     = "spiffy.cicdArtifactRegistryRole"
  project     = var.project_id
  title       = "CloudRun Role for artifact registry"
  description = "Terraform Managed - CloudRun Role for artifact registry"
  permissions = [
    "artifactregistry.repositories.uploadArtifacts",
    "artifactregistry.repositories.downloadArtifacts"
  ]
}

resource "google_project_iam_member" "cloudbuild-artifacts-registry-custom-role-member" {

  count   = var.environment == "prod" ? 1 : 0
  project = google_project.deployment-project.project_id
  role    = google_project_iam_custom_role.cloudbuild-artifacts-registry-custom-role[0].id
  member  = "serviceAccount:${data.terraform_remote_state.dev.outputs.cloudbuild_service_account_email}"
}

# Grant cloudrun (in DEV) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_cloudrun_dev" {

  count      = var.environment == "prod" ? 1 : 0
  project    = google_artifact_registry_repository.artifact_registry_docker[0].project
  location   = google_artifact_registry_repository.artifact_registry_docker[0].location
  repository = google_artifact_registry_repository.artifact_registry_docker[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${data.terraform_remote_state.dev.outputs.project_number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# Grant cloudrun (in PROD) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_cloudrun_prod" {

  count      = var.environment == "prod" ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry_docker[0].location
  repository = google_artifact_registry_repository.artifact_registry_docker[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${google_project.deployment-project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# Grant GKE node pool service accounts (in DEV) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_reader_for_gke_dev" {

  count      = var.environment == "prod" ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry_docker[0].location
  repository = google_artifact_registry_repository.artifact_registry_docker[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${data.terraform_remote_state.dev.outputs.gke_node_pool_service_account_email}"
}

# Grant GKE node pool service accounts (in PROD) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_reader_for_gke_prod" {

  count      = var.environment == "prod" ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry_docker[0].location
  repository = google_artifact_registry_repository.artifact_registry_docker[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_node_pool_service_account.email}"
}

# Grant Union.AI cluster service accounts (in DEV) permissions to read from the artifact registry
# ucuscentral1-flyteworker-mi1e@spiffy-dev-training.iam.gserviceaccount.com
# https://docs.union.ai/integrations/enabling-gcp-resources/enabling-google-artifact-registry#enabling-google-artifact-registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_reader_for_unionai_dev" {

  count      = var.environment == "prod" && var.union_ai_cloud_enabled ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry_docker[0].location
  repository = google_artifact_registry_repository.artifact_registry_docker[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:ucuscentral1-flyteworker-mi1e@spiffy-dev-training.iam.gserviceaccount.com"
}

# Grant Vertex AI service account permissions to read from the artifact registry
# Vertex AI Service Agent service-342792860956@gcp-sa-aiplatform.iam.gserviceaccount.com
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_vertex_ai_default_region" {

  count      = 0
  depends_on = [module.vertex_ai_endpoint_default]
  location   = module.artifact-registry-vertex-ai-docker-default-region[0].location
  repository = module.artifact-registry-vertex-ai-docker-default-region[0].repo_name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.ai_platform_service_account_email}"
}

resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_vertex_ai_secondary_region" {

  count      = 0
  depends_on = [module.vertex_ai_endpoint_default]
  location   = module.artifact-registry-vertex-ai-docker-secondary-region[0].location
  repository = module.artifact-registry-vertex-ai-docker-secondary-region[0].repo_name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${local.ai_platform_service_account_email}"
}

