resource "google_secret_manager_secret" "github-token-secret" {
  secret_id = "github-token-secret"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github-token-secret-version" {
  secret      = google_secret_manager_secret.github-token-secret.id
  secret_data = "github_pat_XXXXX"
}

data "google_iam_policy" "p4sa-secretAccessor" {
  binding {
    role    = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:service-${var.project_number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
    ]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  project = var.project_id
  secret_id   = google_secret_manager_secret.github-token-secret.secret_id
  policy_data = data.google_iam_policy.p4sa-secretAccessor.policy_data
}

resource "google_cloudbuildv2_connection" "github-connection" {
  location = var.region
  name     = "${var.org_name}-github-connection"
  project = var.project_id

  github_config {
    app_installation_id = var.github_app_installation_id
    authorizer_credential {
      oauth_token_secret_version = google_secret_manager_secret_version.github-token-secret-version.id
    }
  }

  lifecycle {
    ignore_changes = [
      github_config
    ]
  }
}

