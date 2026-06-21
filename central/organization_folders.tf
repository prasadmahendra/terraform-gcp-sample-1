resource "google_folder" "spiffy-org-eng-folder" {
  display_name = "engineering"
  parent       = "organizations/${var.org_id}"
}

resource "google_folder" "spiffy-org-eng-gcp-env-folder" {
  display_name = "gcp-env"
  parent       = google_folder.spiffy-org-eng-folder.name
}

### Central environment

resource "google_folder" "spiffy-org-eng-gcp-env-central-folder" {
  display_name = "gcp-env-central"
  parent       = google_folder.spiffy-org-eng-gcp-env-folder.name
}

### PROD environment

resource "google_folder" "spiffy-org-eng-gcp-env-prod-folder" {
  display_name = "gcp-env-prod"
  parent       = google_folder.spiffy-org-eng-gcp-env-folder.name
}

resource "google_folder" "spiffy-org-eng-gcp-env-training-prod-folder" {
  display_name = "gcp-env-training-prod"
  parent       = google_folder.spiffy-org-eng-gcp-env-folder.name
}

### DEV environment

resource "google_folder" "spiffy-org-eng-gcp-env-dev-folder" {
  display_name = "gcp-env-dev"
  parent       = google_folder.spiffy-org-eng-gcp-env-folder.name
}

