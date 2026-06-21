# "roles/iam.securityReviewer"
resource "google_folder_iam_member" "organization_iam_binding_for_security_reviewer_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/iam.securityReviewer"
  member = local.gsuite_security_reviewers_group_id
}

# roles/cloudasset.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_security_reviewer_cloudasset_viewer_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/cloudasset.viewer"
  member = local.gsuite_security_reviewers_group_id
}

# roles/viewer
resource "google_folder_iam_member" "organization_iam_binding_for_security_reviewer_viewer_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/viewer"
  member = local.gsuite_security_reviewers_group_id
}
