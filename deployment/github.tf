data "google_secret_manager_secret_version" "github-access-ssh-known-hosts" {

  count   = 1
  secret  = "cloud-build-github-access-ssh-known-hosts"
  project = google_project.deployment-project.project_id
}

# The noop key is the default and has zero access to any repos.
# This is used to make the secrets management in cloudbuild configs work
data "google_secret_manager_secret_version" "github-access-ssh-noop-key" {

  count   = 1
  secret  = "cloud-build-github-access-ssh-noop-key"
  project = google_project.deployment-project.project_id
}

module "github" {

  count                      = 1
  source                     = "../modules/github"
  github_org_name            = var.github_org_name
  project_id                 = google_project.deployment-project.project_id
  region                     = var.region_default
  github_app_installation_id = var.github_app_installation_id
  org_name                   = var.org_name
  project_number             = google_project.deployment-project.number
}

# this is a hack to get around google_cloudbuildv2_connection.github-connection not workable due to
# frustrating personal access token fine grained permissions issues to make that work! So we manually
# create the link/connection in GCP console and then import it here
import {
  id = "projects/${google_project.deployment-project.project_id}/locations/${var.region_default}/connections/${var.org_name}-github-connection"
  to = module.github[0].google_cloudbuildv2_connection.github-connection
}