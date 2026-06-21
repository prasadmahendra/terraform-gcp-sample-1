# There is no way to create a slack notification channel using terraform due to
# auth_token requirement. auth_token in impossible to obtain without hacking the
# manual setups oauth flow to grab the JWT token! So create the slack channel
# manually and then use terraform to import and create the notification channel in GCP
# (the hacky way is described above and left commented out for posterity!)
data "google_monitoring_notification_channel" "slack_notification_channel" {
  display_name = "GCP Notification Channel (Slack)"
  project      = google_project.deployment-project.project_id
  type         = "slack"
  labels       = {
    "channel_name" = var.environment == "prod" ? "#engineering-alerts" : "#engineering-alerts-dev"
  }
}

resource "google_monitoring_notification_channel" "email_notification_channel" {
  display_name = "GCP Notification Channel (Email)"
  type         = "email"
  labels       = {
    email_address = var.infra_alerts_email_address
  }
  force_delete = false
  project      = google_project.deployment-project.project_id
}