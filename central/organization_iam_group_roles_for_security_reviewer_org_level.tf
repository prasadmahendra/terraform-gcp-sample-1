# iam.securityReviewer
resource "google_organization_iam_member" "organization_iam_binding_for_security_reviewer_org_level" {
  org_id = var.org_id
  role   = "roles/iam.securityReviewer"
  member = local.gsuite_security_reviewers_group_id
}

# Organization Viewer
resource "google_organization_iam_member" "organization_iam_binding_for_org_viewer_org_level" {
  org_id = var.org_id
  role   = "roles/resourcemanager.organizationViewer"
  member = local.gsuite_security_reviewers_group_id
}

resource "google_organization_iam_member" "organization_iam_binding_for_security_reviewer_org_level_for_vanta_scanner" {
  org_id = var.org_id
  role   = "roles/iam.securityReviewer"
  member = local.vanta_scanner_subject_uri
}