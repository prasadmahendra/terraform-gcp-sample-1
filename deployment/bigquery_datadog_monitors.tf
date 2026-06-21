# =============================================================================
# BigQuery Cost Monitoring (Datadog) — Warning to Slack, Critical to OpsGenie
# =============================================================================
#
# Monitors rolling 24h bytes scanned to catch runaway query costs before
# they exhaust the 160 TiB/day project quota (see bigquery_quota.tf).
#
# Escalation path (prod):
#   80 TiB (warning)  → Slack #engineering-alerts
#   128 TiB (critical) → Slack + OpsGenie page
#
# Slack channel resource lives in datadog.tf
# (datadog_integration_slack_channel.datadog-engineering-alerts-slack-channel)
#
# =============================================================================

locals {
  bq_cost_monitor_tags = [
    "env:${var.environment}",
    "service:bigquery",
    "team:analytics",
    "managed-by:terraform",
  ]

  bq_cost_notify = (
    var.environment == "prod"
    ? "@slack-engineering-alerts @oncall-platform-engineering @opsgenie-datadog"
    : "@slack-engineering-alerts-dev"
  )

  bq_cost_notify_warning = (
    var.environment == "prod"
    ? "@slack-engineering-alerts"
    : "@slack-engineering-alerts-dev"
  )
}

resource "datadog_monitor" "bq_query_bytes_scanned" {
  name  = "[${upper(var.environment)}] BigQuery Query Usage High (Managed by Terraform)"
  type  = "query alert"
  query = "sum(last_1d):sum:gcp.bigquery.query.scanned_bytes{project_id:${var.project_id}} > 140737488355328"

  message = <<-EOT
    ## BigQuery Query Usage Alert

    Rolling 24h bytes scanned: {{value}} bytes

    {{#is_warning}}
    Usage has crossed ~50% of the daily quota (80 TiB / 160 TiB).
    Review recent queries: `SELECT user_email, SUM(total_bytes_billed) FROM region-${var.region_default}.INFORMATION_SCHEMA.JOBS WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) AND job_type = 'QUERY' GROUP BY 1 ORDER BY 2 DESC`
    ${local.bq_cost_notify_warning}
    {{/is_warning}}

    {{#is_alert}}
    Usage approaching daily quota limit (128 TiB / 160 TiB). Immediate attention required.
    Queries will be rejected by BigQuery once the 160 TiB quota is exhausted.
    ${local.bq_cost_notify}
    {{/is_alert}}
  EOT

  tags     = local.bq_cost_monitor_tags
  priority = 2

  monitor_thresholds {
    critical          = 140737488355328 # 128 TiB (~80% of quota)
    critical_recovery = 109951162777600 # 100 TiB
    warning           = 87960930222080  # 80 TiB (~50% of quota)
    warning_recovery  = 65970697666560  # 60 TiB
  }

  evaluation_delay    = 900   # GCP metric ingestion lag
  require_full_window = false
  notify_no_data      = false # no data = no queries = fine
  renotify_interval   = 120   # re-alert every 2h if still in violation
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}
