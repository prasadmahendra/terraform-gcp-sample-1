resource "google_folder_iam_member" "organization_iam_binding_for_infra_engineers_owner_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/owner"
  member = local.gsuite_infra_engineers_group_id
}

# Storage Admin
resource "google_folder_iam_member" "organization_iam_binding_for_infra_engineers_storage_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/storage.admin"
  member = local.gsuite_infra_engineers_group_id
}

# BigQuery Admin
resource "google_folder_iam_member" "organization_iam_binding_for_infra_engineers_big_query_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/bigquery.admin"
  member = local.gsuite_infra_engineers_group_id
}
