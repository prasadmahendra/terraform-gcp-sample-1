# place all global/system wide secrets in here

data "google_secret_manager_secret_version" "ratelimits-bypass-key" {
  secret  = "ratelimits-bypass-key"
  project = google_project.deployment-project.project_id
}

data "google_secret_manager_secret_version" "curated-api-key" {
  secret  = "partner-curated-api-key"
  project = google_project.deployment-project.project_id
}

