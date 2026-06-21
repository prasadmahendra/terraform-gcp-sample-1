data "google_secret_manager_secret_version" "elasticsearch_cloud_api_key" {
  secret  = "elasticsearch_cloud_api_key"
  project = google_project.deployment-project.project_id
}
