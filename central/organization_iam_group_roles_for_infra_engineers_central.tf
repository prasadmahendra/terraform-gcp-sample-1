resource "google_folder_iam_member" "organization_iam_binding_for_infra_engineers_owner_for_central" {
  folder  = google_folder.spiffy-org-eng-gcp-env-central-folder.id
  role   = "roles/owner"
  member = local.gsuite_infra_engineers_group_id
}

resource "google_organization_iam_binding" "organization_iam_binding_for_infra_engineers_billing_viewer_for_central" {
  org_id = var.org_id
  role   = "roles/billing.viewer"
  members = [
    local.gsuite_infra_engineers_group_id
  ]
}
