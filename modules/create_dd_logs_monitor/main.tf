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
  default_tags = [
    "env:${var.environment}",
    "service:${var.service_name}",
  ]
}

resource "datadog_monitor_json" "monitor_json" {
  monitor = jsonencode(
    {
      "assets"       : [],
      "draft_status": "published",
      "name" : "[${upper(var.environment)}] ${var.monitor_name}",
      "type" : "log alert",
      "query" : "logs(\"service:${var.service_name} env:${var.environment} status:(error OR warn OR alert)\").index(\"*\").rollup(\"count\").last(\"10m\") > 10",
      "message" : " ${local.slack_alert_channel_name}",
      "tags" : concat(var.additional_tags, local.default_tags),
      "priority" : null,
      "options" : {
        "thresholds" : {
          "critical" : 10,
          "warning" : 3
        },
        "groupby_simple_monitor" : false,
        "new_host_delay" : 300,
        "enable_logs_sample" : true,
        "notify_audit" : false,
        "on_missing_data" : "default",
        "include_tags" : true
      }
    }
  )
}