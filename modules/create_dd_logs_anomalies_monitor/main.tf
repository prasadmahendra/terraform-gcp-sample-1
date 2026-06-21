terraform {
  required_providers {
    datadog = {
      source = "datadog/datadog"
    }
  }
}

locals {
  slack_alert_channel_name_by_chapter = var.chapter != "backend" ? "@slack-engineering-alerts-${var.chapter}-chapter" : "@slack-engineering-alerts"
  slack_alert_channel_name = var.environment == "prod" ? local.slack_alert_channel_name_by_chapter : "${local.slack_alert_channel_name_by_chapter}-dev"
  notify_no_data = var.environment == "prod" ? false : false
  default_tags = [
    "env:${var.environment}",
    "service:${var.service_name}",
  ]
}

resource "datadog_monitor_json" "monitor_json" {
  monitor = jsonencode(
    {
      "assets"       : []
      "draft_status" : "published"
      "name" : "[${upper(var.environment)}] ${var.monitor_name}",
      "type" : "query alert",
      "query" : "avg(last_1d):anomalies(sum:logs{service:${var.service_name} AND status IN (error, warn ) AND env:${var.environment}} by {env,status}.as_count(), 'basic', 2, direction='both', interval=300, alert_window='last_90m', count_default_zero='true') >= 0.95",
      "message" : " ${local.slack_alert_channel_name}",
      "tags" : concat(var.additional_tags, local.default_tags),
      "priority" : var.priority,
      "options" : {
        "thresholds" : {
          "critical" : 0.95,
          "critical_recovery" : 0.10
        },
        "notify_audit" : false,
        "require_full_window" : false,
        "notify_no_data" : local.notify_no_data,
        "renotify_interval" : 30,
        "threshold_windows" : {
          "trigger_window" : "last_90m",
          "recovery_window" : "last_30m"
        },
        "include_tags" : true,
        "new_group_delay" : 60
      }
    }
  )
}
