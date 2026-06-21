resource "google_folder_iam_member" "organization_iam_binding_for_ml_engineers_datastore_access_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/datastore.owner"
  member = local.gsuite_ml_engineers_group_id
  condition {
    title      = "Allow Datastore Owner access for ML Engineers"
    description = "Terraform Managed - Allow Datastore Owner access for ML Engineers"
    # https://cloud.google.com/iam/docs/conditions-overview
    expression = <<EXPR
resource.name.startsWith("projects/${var.project_id}/databases/spiffy-annotations-store") ||
resource.name.startsWith("projects/${var.project_id}/databases/spiffy-chat-sessions-store")
EXPR
  }
}
