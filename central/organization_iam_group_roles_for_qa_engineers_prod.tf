resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_cloud_builds_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/cloudbuild.builds.viewer"
  member = local.gsuite_qa_engineers_group_id
}

# roles/logging.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_logging_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/logging.viewer"
  member = local.gsuite_qa_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_artifact_registry_reader_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id # artifact registry is in prod
  role   = "roles/artifactregistry.reader" # Must be R/O access. Only CI/CD is allowed to push
  member = local.gsuite_qa_engineers_group_id
}
