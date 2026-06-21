# How to create auth token:
# follow steps here: https://stackoverflow.com/questions/65207577/auth-token-for-slack-integration
# Then enter the token in the secret manager on the web console for GCP and name it slack_notification_channel_auth_token
#
#resource "google_monitoring_notification_channel" "slack_notification_channel" {
#  display_name = "GCP Notification Channel"
#  type         = "slack"
#  labels       = {
#    "channel_name" = "#tech-gcp"
#  }
#  sensitive_labels {
#    auth_token = data.google_secret_manager_secret_version.slack_notification_channel_auth_token_version.secret_data
#  }
#  force_delete = false
#}

# There is no way to create a slack notification channel using terraform due to
# auth_token requirement. auth_token in impossible to obtain without hacking the
# manual setups oauth flow to grab the JWT token! So create the slack channel
# manually and then use terraform to import and create the notification channel in GCP
# (the hacky way is described above and left commented out for posterity!)
data "google_monitoring_notification_channel" "slack_notification_channel" {
  display_name = "GCP Notification Channel (Slack)"
  project      = google_project.deployment-central.project_id
  type         = "slack"
  labels       = {
    "channel_name" = "#engineering-alerts"
  }
}

resource "google_monitoring_notification_channel" "email_notification_channel" {
  display_name = "GCP Notification Channel (Email)"
  type         = "email"
  labels       = {
    email_address = var.infra_alerts_email_address
  }
  force_delete = false
  project      = google_project.deployment-central.project_id
}