# Grant CircleCI service account permissions to read from the artifact registry
resource "google_artifact_registry_repository_iam_member" "artifact_registry_repository_iam_member_circleci" {

  count      = var.environment == "prod" ? 1 : 0
  location   = google_artifact_registry_repository.artifact_registry_docker[0].location
  repository = google_artifact_registry_repository.artifact_registry_docker[0].name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:spiffy-react-components-sa@spiffy-ai-dev.iam.gserviceaccount.com"
}

# Let CircleCI SA *read Cloud Build builds* in the dev project (spiffy-ai-dev)
resource "google_project_iam_member" "circleci_cloudbuild_viewer" {
  count    = var.environment == "dev" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudbuild.builds.viewer"
  member  = "serviceAccount:spiffy-react-components-sa@spiffy-ai-dev.iam.gserviceaccount.com"
}

# Custom role for CircleCI SA to manage Cloud Build in prod
resource "google_project_iam_custom_role" "circleci_cloudbuild_custom_role" {

  count       = var.environment == "prod" ? 1 : 0
  role_id     = "spiffy.circleCiCloudBuildRole"
  project     = var.project_id
  title       = "CircleCI CloudBuild Role"
  description = "Terraform Managed - CircleCI role for Cloud Build triggers and builds management"
  permissions = [
    "cloudbuild.builds.update",
    "cloudbuild.builds.list",
    "cloudbuild.builds.get",
    "cloudbuild.builds.create"
  ]
}

resource "google_project_iam_member" "circleci_cloudbuild_custom_role_member" {

  count   = var.environment == "prod" ? 1 : 0
  project = var.project_id
  role    = google_project_iam_custom_role.circleci_cloudbuild_custom_role[0].id
  member  = "serviceAccount:spiffy-react-components-sa@spiffy-ai-dev.iam.gserviceaccount.com"
}

# Allow CircleCI SA to impersonate the prod promote SA (required to run triggers)
resource "google_service_account_iam_member" "circleci_can_impersonate_promote_sa" {
  count              = var.environment == "prod" ? 1 : 0
  service_account_id = google_service_account.cloudbuild_service_account_for_promoting_builds_to_prod[0].name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:spiffy-react-components-sa@spiffy-ai-dev.iam.gserviceaccount.com"
}