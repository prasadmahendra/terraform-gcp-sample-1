# Datadog AWS integration
# https://medium.com/sardineai/integrating-gcp-with-datadog-with-terraform-d88c5c65dc0a

# Create new integration_gcp_sts resource
# Service account should have compute.viewer, monitoring.viewer, and cloudasset.viewer roles.
resource "google_service_account" "datadog_integration" {
  account_id   = "datadogintegration"
  display_name = "Datadog integration service account"
  project      = var.project_id
}


resource "datadog_integration_gcp_sts" "datadog_integration_gcp" {
  client_email    = google_service_account.datadog_integration.email
  host_filters = []
  automute        = true
  is_cspm_enabled = false
  account_tags = [
    "env:${var.environment}"
  ]
}

# Grant token creator role to the Datadog principal account.
resource "google_service_account_iam_member" "sa_iam" {
  service_account_id = google_service_account.datadog_integration.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member = format("serviceAccount:%s", datadog_integration_gcp_sts.datadog_integration_gcp.delegate_account_email)
}

resource "google_project_iam_member" "datadog-connect" {
  for_each = toset([
    "roles/cloudasset.viewer",
    "roles/compute.viewer",
    "roles/monitoring.viewer",
  ])
  role    = each.key
  member  = "serviceAccount:${google_service_account.datadog_integration.email}"
  project = var.project_id
}

resource "google_pubsub_topic" "datadog-logs-export-topic" {
  name    = "datadog-logs-export-topic"
  project = var.project_id
}

resource "google_pubsub_subscription" "datadog-logs-export-subscription" {

  # Disable exporting GCP logs to Datadog this way. Most of this stuff is noisy and not useful.
  count                      = 1
  name                       = "datadog-logs"
  topic                      = google_pubsub_topic.datadog-logs-export-topic.name
  project                    = var.project_id
  message_retention_duration = "604800s"
  retain_acked_messages      = false
  ack_deadline_seconds       = 60

  push_config {
    push_endpoint = "${var.datadog_logs_intake_endpoint}?dd-api-key=${var.datadog_api_key}&dd-protocol=gcp&ddtags=env:${var.environment}"
  }
}

resource "google_logging_project_sink" "datadog-logging-project-sink" {
  name                   = "datadog-sink"
  destination            = "pubsub.googleapis.com/${google_pubsub_topic.datadog-logs-export-topic.id}"
  filter                 = ""
  unique_writer_identity = true
  project                = var.project_id
}

resource "google_project_iam_member" "pubsub-publisher-permisson" {
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.datadog-logging-project-sink.writer_identity
  project = var.project_id
}