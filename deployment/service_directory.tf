resource "google_service_directory_namespace" "service_directory_namespace_backend_apps" {
  provider     = google-beta
  namespace_id = "apps-backend-ns"
  location     = var.region_default
  project      = var.project_id

  labels = {
    env  = var.environment
    team = var.default_eng_team
  }
}