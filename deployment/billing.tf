# requires a quota project during auth - gcloud auth application-default set-quota-project <project-id>
resource "google_billing_budget" "budget" {

  count           = 1
  depends_on      = [google_project_service.all]
  billing_account = local.billing_account_id
  display_name    = "${var.environment} billing budget"
  budget_filter {
    projects = ["projects/${google_project.deployment-project.number}"]
  }
  amount {
    specified_amount {
      currency_code = "USD"
      units         = "5000"
    }
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }
  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email_notification_channel.id,
      #data.google_monitoring_notification_channel.slack_notification_channel_for_quota_project.id,
    ]
    disable_default_iam_recipients = false
  }
}

#data "google_monitoring_notification_channel" "slack_notification_channel_for_quota_project" {
#  display_name = "GCP Notification Channel (Slack)"
#  project      = var.project_id_for_quotas
#  type         = "slack"
#  labels       = {
#    "channel_name" = "#tech-gcp"
#  }
#}