# =============================================================================
# Analytics Gateway Monitoring (Datadog) — Golden Signals
# =============================================================================
#
# Monitors for the analytics data plane: gateway error rate, latency,
# streams processor errors, and rate limit saturation.
#
# Spec: https://github.com/spiffy-ai/envive/pull/6
#
# Escalation path:
#   Datadog monitor fires → Slack #engineering-alerts (prod)
#                         → Slack #engineering-alerts-dev (dev)
#
# =============================================================================

locals {
  analytics_gw_monitor_tags = [
    "env:${var.environment}",
    "service:analytics-gateway",
    "team:backend",
    "managed-by:terraform",
  ]

  analytics_gw_notify = (
    var.environment == "prod"
    ? "@slack-engineering-alerts"
    : "@slack-engineering-alerts-dev"
  )
}

# -----------------------------------------------------------------------------
# Gateway Error Rate — percentage of non-2xx responses
#
# Source: APM standard metrics (ddtrace-run on analytics-gateway)
# Thresholds tuned from backtest: normal operation is ~0%, so 1% warning
# catches subtle regressions while 5% critical flags serious failures.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "analytics_gateway_error_rate" {
  name  = "[${upper(var.environment)}] Analytics Gateway Error Rate (Managed by Terraform)"
  type  = "query alert"
  query = "sum(last_5m):trace.flask.request.errors{service:analytics-gateway,env:${var.environment}}.as_count() / trace.flask.request.hits{service:analytics-gateway,env:${var.environment}}.as_count() > 0.05"

  message = <<-EOT
    ## Analytics Gateway Error Rate

    Error rate for analytics-gateway is above threshold.

    **Current value:** {{value}}
    **Threshold:** {{threshold}}

    ### Triage
    1. Open DD Log Explorer: `service:analytics-gateway status:error`
    2. Check `status_code` facet — which code is dominant (429, 400, 500)?
    3. Check `org_short_name` facet — one merchant or many?

    Runbook: https://github.com/spiffy-ai/runbooks/blob/main/analytics/gateway-alerts.md#alert-gateway-error-rate-1-warning-5-critical

    ${local.analytics_gw_notify}
  EOT

  tags     = local.analytics_gw_monitor_tags
  priority = 2

  monitor_thresholds {
    critical          = 0.05
    critical_recovery = 0.03
    warning           = 0.01
    warning_recovery  = 0.005
  }

  require_full_window = false
  notify_no_data      = false
  renotify_interval   = 60
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}

# -----------------------------------------------------------------------------
# Gateway Latency P95 — slow event acceptance / PubSub publish
#
# Source: APM standard metrics (ddtrace-run on analytics-gateway)
# The gateway just publishes to PubSub and returns, so high latency suggests
# PubSub or auth issues.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "analytics_gateway_latency_p95" {
  name  = "[${upper(var.environment)}] Analytics Gateway Latency P95 (Managed by Terraform)"
  type  = "query alert"
  query = "percentile(last_5m):p95:trace.flask.request{service:analytics-gateway,env:${var.environment}} > 1"

  message = <<-EOT
    ## Analytics Gateway Latency P95

    P95 latency for analytics-gateway is above threshold.

    **Current value:** {{value}}s
    **Threshold:** {{threshold}}s

    ### Triage
    1. Check APM traces for `service:analytics-gateway` — look for slow spans
    2. Check GCP PubSub publish latency in GCP Console
    3. Check Waitress queue depth: `python.waitress.queue`

    Runbook: https://github.com/spiffy-ai/runbooks/blob/main/analytics/gateway-alerts.md#alert-gateway-latency-p95-500ms-warning-1s-critical

    ${local.analytics_gw_notify}
  EOT

  tags     = local.analytics_gw_monitor_tags
  priority = 2

  monitor_thresholds {
    critical          = 1.0
    critical_recovery = 0.8
    warning           = 0.5
    warning_recovery  = 0.4
  }

  require_full_window = false
  notify_no_data      = false
  renotify_interval   = 60
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}

# -----------------------------------------------------------------------------
# Streams Callback Errors — async processor silently dropping messages
#
# Source: Custom StatsD counter (analytics.streams_processor.stream_data_callback.error)
# These errors are acked but not processed — silent data loss.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "analytics_streams_callback_errors" {
  name  = "[${upper(var.environment)}] Analytics Streams Callback Errors (Managed by Terraform)"
  type  = "query alert"
  query = "sum(last_5m):sum:analytics.streams_processor.stream_data_callback.error{*}.as_rate() > 50"

  message = <<-EOT
    ## Streams Callback Errors

    Streams processor callback errors are above threshold.

    **Current value:** {{value}}/min
    **Threshold:** {{threshold}}/min

    These errors are silently swallowed — messages are acked but not processed.

    ### Triage
    1. Check streams processor pod logs for stack traces
    2. Identify pattern: schema mismatch, Amplitude API failure, or CDP provider timeout
    3. Check recent deploys: `kubectl rollout history deployment/streams-processor -n apps-services-ns`

    Runbook: https://github.com/spiffy-ai/runbooks/blob/main/analytics/gateway-alerts.md#alert-streams-callback-errors-10min-warning-50min-critical

    ${local.analytics_gw_notify}
  EOT

  tags = [
    "env:${var.environment}",
    "service:streams-processor",
    "team:backend",
    "managed-by:terraform",
  ]
  priority = 2

  monitor_thresholds {
    critical          = 50
    critical_recovery = 30
    warning           = 10
    warning_recovery  = 5
  }

  require_full_window = false
  notify_no_data      = false
  renotify_interval   = 60
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}

# -----------------------------------------------------------------------------
# Client Error Spike (400 + 429) — silent analytics data loss
#
# Source: APM trace metrics filtered to 400 and 429 status codes.
# 400 = malformed SDK requests, 429 = rate limit exceeded.
# Both cause events to be silently dropped.
# Warning only — investigation needed to distinguish legitimate vs broken.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "analytics_gateway_client_error_spike" {
  name  = "[${upper(var.environment)}] Analytics Gateway Client Errors 400/429 (Managed by Terraform)"
  type  = "query alert"
  query = "sum(last_5m):sum:trace.flask.request.hits.by_http_status{service:analytics-gateway,http.status_code:400,env:${var.environment}}.as_count() + sum:trace.flask.request.hits.by_http_status{service:analytics-gateway,http.status_code:429,env:${var.environment}}.as_count() > 40"

  message = <<-EOT
    ## Client Error Spike (400 + 429)

    Analytics gateway is returning elevated 400/429 responses — events are being silently dropped.

    **Current value:** {{value}} in 5min
    **Threshold:** {{threshold}}

    ### Triage
    1. Open DD Log Explorer: `service:analytics-gateway status:(error) status_code:(400 OR 429)`
    2. Check `status_code` — is it 400 (bad request) or 429 (rate limit)?
    3. Check `org_short_name` facet — one merchant or many?
    4. **429:** Legitimate traffic spike, or runaway integration?
    5. **400:** Malformed SDK requests — check recent deploys in `envive-analytics-sdk` or `shopify-app`

    Runbook: https://github.com/spiffy-ai/runbooks/blob/main/analytics/gateway-alerts.md#alert-client-error-spike-400429-20-warning-40-critical

    ${local.analytics_gw_notify}
  EOT

  tags     = local.analytics_gw_monitor_tags
  priority = 3

  monitor_thresholds {
    critical          = 40
    critical_recovery = 20
    warning           = 20
    warning_recovery  = 10
  }

  require_full_window = false
  notify_no_data      = false
  renotify_interval   = 60
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}
