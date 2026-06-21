# BigQuery query cost protection — server-side daily quota.
# Enforced by BigQuery regardless of client; queries exceeding
# the limit are rejected before running (no charge).
# Quota resets at midnight Pacific Time.
#
# Per-user quota (QueryUsagePerUserPerDay) is intentionally omitted:
# BQ does not support per-service-account overrides, so a blanket
# per-user limit would constrain the API service account the same
# as human engineers. Per-query maximum_bytes_billed in code
# provides the API-level protection instead.

resource "google_service_usage_consumer_quota_override" "bq_query_usage_per_day" {
  provider       = google-beta
  project        = var.project_id
  service        = "bigquery.googleapis.com"
  metric         = urlencode("bigquery.googleapis.com/quota/query/usage")
  limit          = urlencode("/d/project")
  override_value = "167772160" # 160 TiB/day in MiB (160 × 1024 × 1024) ≈ $1,000/day at on-demand pricing
  force          = true

  lifecycle {
    prevent_destroy = true
  }
}
