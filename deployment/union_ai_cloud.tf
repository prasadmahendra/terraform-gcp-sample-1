data "google_secret_manager_secret_version" "union_cloud_app_secret" {
  count   = var.union_ai_cloud_enabled ? 1 : 0
  secret  = "union_cloud_app_secret"
  project = google_project.deployment-project.project_id
}
