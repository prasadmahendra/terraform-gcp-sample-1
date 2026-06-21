data "google_secret_manager_secret_version" "datadog_api_key" {
  secret  = "datadog_api_key"
  project = google_project.deployment-project.project_id
}

data "google_secret_manager_secret_version" "datadog_app_key" {
  secret  = "datadog_app_key"
  project = google_project.deployment-project.project_id
}

module "datadog" {
  source                       = "../modules/datadog"
  environment                  = var.environment
  project_id                   = google_project.deployment-project.project_id
  datadog_api_key              = data.google_secret_manager_secret_version.datadog_api_key.secret_data
  datadog_app_key              = data.google_secret_manager_secret_version.datadog_app_key.secret_data
  datadog_endpoint             = var.datadog_endpoint
  datadog_logs_intake_endpoint = var.datadog_logs_intake_endpoint
}

# https://docs.datadoghq.com/logs/guide/manage_logs_and_metrics_with_terraform/
resource "datadog_integration_slack_channel" "datadog-engineering-alerts-slack-channel" {

  depends_on   = [data.google_monitoring_notification_channel.slack_notification_channel]
  account_name = "Spiffy"
  channel_name = var.environment == "prod" ? "#engineering-alerts" : "#engineering-alerts-dev"

  display {
    message  = true
    notified = true
    snapshot = true
    tags     = true
  }
}

resource "datadog_integration_slack_channel" "datadog-engineering-alerts-analytics-slack-channel" {

  depends_on   = [data.google_monitoring_notification_channel.slack_notification_channel]
  account_name = "Spiffy"
  channel_name = var.environment == "prod" ? "#engineering-alerts-analytics" : "#engineering-alerts-analytics-dev"

  display {
    message  = true
    notified = true
    snapshot = true
    tags     = true
  }
}
