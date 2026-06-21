resource "random_string" "random_suffix" {
  length  = 8
  special = false
}

resource "google_artifact_registry_repository" "artifact_registry" {

  project       = var.project_id
  location      = var.region
  repository_id = var.repo_name
  description   = "${var.repo_name} (${var.environment}) ${var.registry_format} registry"
  format        = var.registry_format

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-prerelease"
    action = "DELETE"
    condition {
      tag_state    = "TAGGED"
      tag_prefixes = ["alpha", "v0"]
      older_than   = "2592000s"
    }
  }
  cleanup_policies {
    id     = "keep-tagged-release"
    action = "KEEP"
    condition {
      tag_state    = "TAGGED"
      tag_prefixes = ["prod", "latest", "v"]
    }
  }
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "15552000s"  # 90 days
    }
  }
}

#
# Registry access control
# https://cloud.google.com/artifact-registry/docs/access-control

# Allow cloud-build service acccount in DEV to upload artifacts
resource "google_project_iam_custom_role" "cloudbuild-artifacts-registry-custom-role" {

  role_id     = "spiffy.cicdArtifactRegistryRole_${random_string.random_suffix.result}"
  project     = var.project_id
  title       = "CloudRun Role for artifact registry ${var.registry_format}"
  description = "Terraform Managed - CloudRun Role for artifact registry"
  permissions = [
    "artifactregistry.repositories.uploadArtifacts",
    "artifactregistry.repositories.downloadArtifacts"
  ]
}

resource "google_project_iam_member" "cloudbuild-artifacts-registry-custom-role-member" {

  project = var.project_id
  role    = google_project_iam_custom_role.cloudbuild-artifacts-registry-custom-role.id
  member  = "serviceAccount:${var.cloudbuild_service_account_email}"
}

# Grant cloudrun (in DEV) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_cloudrun_dev" {

  location   = google_artifact_registry_repository.artifact_registry.location
  repository = google_artifact_registry_repository.artifact_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${var.project_number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# Grant cloudrun (in PROD) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_cloudrun_prod" {

  location   = google_artifact_registry_repository.artifact_registry.location
  repository = google_artifact_registry_repository.artifact_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${var.project_number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# Grant GKE node pool service accounts (in DEV) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_reader_for_gke_dev" {

  count      = var.environment == "prod" ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry.location
  repository = google_artifact_registry_repository.artifact_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_node_pool_service_account_email_for_dev}"
}

# Grant GKE node pool service accounts (in PROD) permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_reader_for_gke_prod" {

  count      = var.environment == "prod" ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry.location
  repository = google_artifact_registry_repository.artifact_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_node_pool_service_account_email_for_prod}"
}
