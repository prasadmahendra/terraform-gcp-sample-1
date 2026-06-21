data "google_storage_transfer_project_service_account" "storage_transfer_project_service_account" {
  project = var.project_name
}

resource "google_project_iam_member" "storage_transfer_project_service_account_pubsub_editor_role" {
  project = var.project_name
  role    = "roles/pubsub.editor"
  member  = "serviceAccount:${data.google_storage_transfer_project_service_account.storage_transfer_project_service_account.email}"
}

resource "google_storage_transfer_agent_pool" "storage_transfer_agent_pool" {
  project      = var.project_name
  depends_on = [google_project_iam_member.storage_transfer_project_service_account_pubsub_editor_role]
  name         = var.agent_pool_name
  display_name = var.agent_pool_description
  bandwidth_limit {
    limit_mbps = var.bandwidth_limit_mbps
  }
}