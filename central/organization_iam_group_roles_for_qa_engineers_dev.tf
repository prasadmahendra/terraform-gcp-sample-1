resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_cloud_builds_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/cloudbuild.builds.viewer"
  member = local.gsuite_qa_engineers_group_id
}

# roles/logging.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_logging_viewer_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/logging.viewer"
  member = local.gsuite_qa_engineers_group_id
}

# roles/compute.networkViewer
resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_compute_network_viewer_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/compute.networkViewer"
  member = local.gsuite_qa_engineers_group_id
}

# roles/compute.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_compute_viewer_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/compute.viewer"
  member = local.gsuite_qa_engineers_group_id
}

# https://firebase.google.com/docs/projects/iam/roles-predefined-all-products
# roles/firebase.admin
resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_firebase_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/firebase.admin"
  member = local.gsuite_qa_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_datastore_access_for_dev" {

  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role    = "roles/datastore.user"
  member = local.gsuite_qa_engineers_group_id

  condition {
    title       = "Allow datastore access"
    description = "Terraform Managed - Allow datastore access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-monitoring-results}") ||
resource.name.startsWith("projects/_/buckets/spiffy-monitoring-store}")
EXPR
  }
}

resource "google_folder_iam_member" "organization_iam_binding_for_qa_engineers_artifact_registry_reader_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id # artifact registry is in prod
  role   = "roles/artifactregistry.reader" # Must be R/O access. Only CI/CD is allowed to push
  member = local.gsuite_qa_engineers_group_id
}
