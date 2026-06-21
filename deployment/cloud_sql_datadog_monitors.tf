# =============================================================================
# Cloud SQL Disk Monitoring (Datadog) — On-Call Escalation via OpsGenie
# =============================================================================
#
# These monitors leverage GCP Cloud SQL metrics already flowing into Datadog
# via the datadog_integration_gcp_sts integration (see modules/datadog/).
#
# They complement the existing GCP Cloud Monitoring alerts in
# cloud_monitoring.tf by adding on-call escalation through OpsGenie, following
# the same escalation pattern used by commerce-api synthetic tests.
#
# Escalation path (prod):
#   Datadog monitor fires → Slack #engineering-alerts
#                         → OpsGenie @opsgenie-datadog → on-call engineer
#
# =============================================================================

locals {
  cloudsql_monitor_tags = [
    "env:${var.environment}",
    "service:cloud-sql",
    "team:infrastructure",
    "managed-by:terraform",
  ]

  cloudsql_escalation_message = (
    var.environment == "prod"
    ? "@slack-engineering-alerts @oncall-platform-engineering @opsgenie-datadog"
    : "@slack-engineering-alerts-dev"
  )
}

# -----------------------------------------------------------------------------
# Cloud SQL Disk Utilization — PRIMARY ON-CALL ALERT
#
# This is the most critical alert: disk filling up can cause write failures
# and database downtime. Pages on-call at 90%, warns at 80%.
#
# Metric: gcp.cloudsql.database.disk.utilization (0.0–1.0 ratio)
# Grouped by database_id so each instance alerts independently.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "cloud_sql_disk_utilization" {
  name    = "[${upper(var.environment)}] Cloud SQL Disk Utilization High (Managed by Terraform)"
  type    = "query alert"
  query   = "avg(last_15m):avg:gcp.cloudsql.database.disk.utilization{project_id:${var.project_id}} by {database_id} > 0.985"
  message = <<-EOT
    ## Cloud SQL Disk Utilization Alert

    Disk utilization for **{{database_id.name}}** has exceeded the threshold.

    **Current value:** {{value}}
    **Threshold:** {{threshold}}

    ### Recommended Actions
    1. Check for unexpected data growth or bulk operations
    2. Review and clean up unused data, old backups, or temporary tables
    3. Consider increasing disk size (Cloud SQL supports online disk resize)
    4. Verify automatic storage increase is enabled in Cloud SQL instance settings

    ${local.cloudsql_escalation_message}
  EOT

  tags     = local.cloudsql_monitor_tags
  priority = 1

  monitor_thresholds {
    critical          = 0.985
    warning           = 0.8
    warning_recovery  = 0.75
  }

  # GCP metrics have a known 3-10 min ingestion lag into Datadog.
  # evaluation_delay prevents evaluating stale/incomplete windows and avoids
  # the "data cliff" flapping pattern common with GCP-sourced metrics.
  evaluation_delay    = 900
  # Don't require a full evaluation window — sparse GCP metric delivery can
  # cause the monitor to silently skip evaluations without this set to false.
  require_full_window = false
  notify_no_data      = true
  # 60 min (not 30) — gives the integration time to recover from brief
  # disruptions before paging on-call for a missing-data condition.
  no_data_timeframe   = 60
  renotify_interval   = 60
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}
# I/O monitoring (read/write ops) is intentionally handled in GCP Cloud Monitoring
# (see cloud_monitoring.tf → google_monitoring_alert_policy.disk_io_alert_for_cloud_sql).
#
# Reasons for NOT duplicating I/O monitors here:
#   1. Datadog anomaly detection (the only self-scaling option) requires Infrastructure Pro plan (~$23/host/mo vs $15 Essentials).
#   2. Fixed thresholds break silently as Cloud SQL autoscales disk (IOPS provision ~30/GB on SSD).
#   3. GCP Cloud Monitoring is free for native GCP metrics and already notifies Slack + email.
