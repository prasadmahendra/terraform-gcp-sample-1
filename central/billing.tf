#resource "google_billing_budget" "budget" {
#
#  depends_on      = [google_project_service.all]
#  billing_account = data.google_billing_account.acct.id
#  display_name    = "${var.environment} billing budget"
#  budget_filter {
#    projects = ["projects/${google_project.deployment-central.number}"]
#  }
#  amount {
#    specified_amount {
#      currency_code = "USD"
#      units         = "100"
#    }
#  }
#  threshold_rules {
#    threshold_percent = 1.0
#  }
#  threshold_rules {
#    threshold_percent = 1.0
#    spend_basis       = "FORECASTED_SPEND"
#  }
#  all_updates_rule {
#    monitoring_notification_channels = [
#      slack_notification_channel.email_notification_channel.id,
#    ]
#    disable_default_iam_recipients = true
#  }
#}