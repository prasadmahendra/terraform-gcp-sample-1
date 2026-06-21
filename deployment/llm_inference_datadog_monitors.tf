# =============================================================================
# LLM Inference Service Monitoring (Datadog) — On-Call Escalation via OpsGenie
# =============================================================================
#
# Covers the vLLM inference services (llm-inference-svc-llama-3-*). The gap
# this closes: on 2026-04-29 the usc1 quantized canary crash-looped for 4d23h
# (1608 restarts) due to local-SSD exhaustion, returning 502 to all callers.
# No alert paged on-call — only a Slack channel notification existed.
#
# Escalation path (prod):
#   Datadog monitor fires → Slack #engineering-alerts
#                         → OpsGenie @opsgenie-datadog → on-call engineer
#
# Cost discipline: only 4 resources total (3 monitors + 1 synthetic), each
# covers a failure mode the others miss. No redundant overlap.
#
#   | Failure mode             | (1) replicas | (2) synthetic | (3) restart | (4) cuda |
#   |--------------------------|:------------:|:-------------:|:-----------:|:--------:|
#   | Pod crash loop           | ✅ eventually| ✅            | ✅ earlier  | -        |
#   | Pod can't schedule       | ✅           | ✅            | -           | -        |
#   | NEG/LB drift, DNS, cert  | -            | ✅            | -           | -        |
#   | Slow degradation         | -            | ✅            | -           | -        |
#   | CUDA regression          | -            | -             | -           | ✅       |
#
# =============================================================================

locals {
  llm_inference_monitor_tags = [
    "env:${var.environment}",
    "service:llm-inference",
    "team:backend",
    "managed-by:terraform",
  ]

  llm_inference_escalation_message = (
    var.environment == "prod"
    ? "@slack-engineering-alerts @oncall-platform-engineering @opsgenie-datadog"
    : "@slack-engineering-alerts-dev"
  )

  llm_inference_slack_only_message = (
    var.environment == "prod"
    ? "@slack-engineering-alerts"
    : "@slack-engineering-alerts-dev"
  )

  # Match all vLLM inference deployments. Grouping by kube_deployment ensures
  # each region (usc1, usw1) and each pod variant (canary, primary, qtz)
  # alerts independently — a single noisy deployment doesn't mask the others.
  llm_inference_deployment_filter = "kube_deployment:llm-inference-svc-llama-3-*"

  # Public hostnames probed by the synthetic /health check. Keep the list short:
  # one synthetic test per host, evaluated every 60s, costs roughly $5-15/mo each.
  #
  # Only probe endpoints whose base deployment is actually serving. qtz-usc1 is
  # intentionally desired=0 (scaled to zero for cost, services.tf:530) — its
  # spot-cap sibling carries the canary load instead — so the public FQDN has no
  # backend and a /health probe is a permanent false page. Re-add "qtz-usc1" here
  # only if that deployment's number_of_replicas goes back above 0.
  llm_inference_synthetic_endpoints = var.environment == "prod" ? {
    "qtz-usw1" = "https://inference-llama-3-70b-qtz-usw1.spiffy.ai/health"
  } : {}
}

# -----------------------------------------------------------------------------
# (1) All Replicas Unavailable — PRIMARY ON-CALL ALERT
#
# Direct correlate of "users see 502s". Fires regardless of root cause: crash
# loop, scheduling failure, capacity exhaustion. The 2026-04-29 incident
# triggered this exact condition for four days without paging.
#
# Query is `replicas_unavailable / replicas_desired > 0.99`. Using the ratio
# avoids false positives on deployments that intentionally have desired=0
# (e.g., the `qtz-usc1` base block at services.tf:483 — canary load runs on
# the sibling `-spot-cap` deployment instead). When desired=0 the denominator
# is 0 and the ratio resolves to null (no data). Such series must NOT page:
# notify_no_data = false (below) so a desired=0 deployment is ignored instead
# of raising a "No Data" alert. Threshold 0.99 fires only when 100% of desired
# replicas are unavailable (full outage); a partial degradation like 1/3 down
# would yield 0.33 and stay below threshold (use a separate alert if partial
# coverage is wanted).
#
# Verified against real DD data: ratio is null for `qa-usw1` and `qtz-usc1`
# (both desired=0), 0 for all healthy deployments. The prior config set
# notify_no_data=true, so those null series paged on-call every ~30m as
# recurring "No Data" alerts — the bug this fixes.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "llm_inference_no_ready_replicas" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "[${upper(var.environment)}] LLM Inference Deployment All Replicas Unavailable (Managed by Terraform)"
  type    = "query alert"
  query   = "min(last_5m):min:kubernetes_state.deployment.replicas_unavailable{${local.llm_inference_deployment_filter}} by {kube_deployment} / min:kubernetes_state.deployment.replicas_desired{${local.llm_inference_deployment_filter}} by {kube_deployment} > 0.99"
  message = <<-EOT
    ## LLM Inference Deployment Down — Users Seeing 502s

    Deployment **{{kube_deployment.name}}** has 100% of desired replicas
    unavailable. All requests routed to this backend pool will return 502
    Bad Gateway.

    **Unavailable / desired ratio:** {{value}}

    ### Triage
    1. `kubectl get pods -n apps-llm-ns | grep {{kube_deployment.name}}` — pod state
    2. If CrashLoopBackOff: `kubectl logs -n apps-llm-ns <pod> -c <container> --previous --tail=80`
    3. Common root causes:
       - Local SSD exhausted (see `start_vllm_h100_quantized.sh` orphan tempdirs)
       - Node out of GPU capacity (NAP fallback to wrong accelerator)
       - vLLM OOM / CUDA error on startup
    4. Quick recovery: `kubectl cordon <node>; kubectl delete pod <pod>` to force reschedule on fresh node.

    ${local.llm_inference_escalation_message}
  EOT

  tags     = local.llm_inference_monitor_tags
  priority = 1

  monitor_thresholds {
    critical = 0.99
  }

  require_full_window = false
  notify_no_data      = false # desired=0 deployments (qtz-usc1, qa-usw1) make the ratio null; a null series must not page
  renotify_interval   = 30
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}

# -----------------------------------------------------------------------------
# (3) Container Restart Burst — earlier warning, complements (1) and (2)
#
# Fires 5-10 min before (1) becomes true. Catches crash loops while replicas
# still toggle ready/not-ready. CrashLoopBackOff state monitor was deliberately
# omitted — same loop, fires later, would just duplicate paging cost.
#
# `kubernetes.containers.restarts` is a cumulative counter (per-pod kubelet
# restart count, monotonically increasing). `as_count()` does NOT derive a
# delta against this metric — it just multiplies the running value by the
# sample count, so a stable pod with 30 lifetime restarts would always sum
# to thousands and trip any threshold. Verified empirically on 2026-04-29:
# stable pod with 23 restarts and 0 recent restarts returned `as_count`=5520
# over 2h, while `diff()` correctly returned 0.
#
# `diff()` reports the delta between samples; `sum(last_10m):diff(...)` is
# the total new restarts inside the 10-minute window — the actual burst
# signal we want.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "llm_inference_restart_burst" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "[${upper(var.environment)}] LLM Inference Container Restart Burst (Managed by Terraform)"
  type    = "query alert"
  query   = "sum(last_10m):diff(max:kubernetes.containers.restarts{${local.llm_inference_deployment_filter}} by {kube_deployment,pod_name}) > 5"
  message = <<-EOT
    ## LLM Inference Pod Restart Burst

    Pod **{{pod_name.name}}** (deployment **{{kube_deployment.name}}**) restarted
    more than 5 times in 10 minutes — likely entering CrashLoopBackOff.

    **Restart count in window:** {{value}}

    ### Triage
    1. `kubectl logs -n apps-llm-ns {{pod_name.name}} -c <container> --previous --tail=80`
    2. Look for ENOSPC, CUDA errors, OOM, missing files on local SSD.
    3. If disk full: `kubectl debug node/<node> -it --image=busybox --profile=sysadmin -- sh -c 'rm -rf /host/mnt/stateful_partition/data/ssd/copy-*'`

    Investigate before kubelet's exponential backoff stretches restart gaps and
    the pod becomes effectively dark.

    ${local.llm_inference_escalation_message}
  EOT

  tags     = local.llm_inference_monitor_tags
  priority = 1

  monitor_thresholds {
    critical = 5
    warning  = 2
  }

  require_full_window = false
  notify_no_data      = false
  renotify_interval   = 60
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}

# -----------------------------------------------------------------------------
# (4) vLLM CUDA Crash Logs — Slack only (warning)
#
# Catches the recurring CUDA illegal memory access bug. Auto-extracted
# `image_tag` is included in the group key so the alert title carries the
# vLLM version directly — no manual "which image is this on?" triage needed.
#
# A crash on a v0.10.x image = the known bug, upgrade the service.
# A crash on a v0.17.x image = a real regression, escalate to backend.
# -----------------------------------------------------------------------------
resource "datadog_monitor" "llm_inference_cuda_crash_logs" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "[${upper(var.environment)}] LLM Inference CUDA Crash Detected — {{service.name}} ({{image_tag.name}}) (Managed by Terraform)"
  type    = "log alert"
  query   = "logs(\"service:llm-inference-svc-llama-3-* (\\\"illegal memory access\\\" OR \\\"CUDA error\\\")\").index(\"*\").rollup(\"count\").by(\"service,image_tag\").last(\"15m\") > 0"
  message = <<-EOT
    Service **{{service.name}}** running image tag **{{image_tag.name}}**
    logged a CUDA error in the last 15 minutes.

    [Open logs](https://us5.datadoghq.com/logs?query=service%3A{{service.name}}+%22illegal+memory+access%22)

    ${local.llm_inference_slack_only_message}
  EOT

  tags     = local.llm_inference_monitor_tags
  priority = 2

  monitor_thresholds {
    critical = 0
  }

  require_full_window = false
  notify_no_data      = false
  renotify_interval   = 0
  notify_audit        = false
  include_tags        = true
  timeout_h           = 0
}

# -----------------------------------------------------------------------------
# (2) Synthetic /health Check — user-perspective ground truth
#
# Independent of any k8s-side signal. Catches NEG drift, DNS, LB misconfig,
# cert expiry — failure modes invisible to (1) and (3). One test per public
# inference host, evaluated every 60s from a single location. retry{count=2}
# absorbs transient single-location blips so we don't burn paging on noise.
#
# Cost note: each synthetic API test bills per evaluation. Single location +
# 60s tick keeps it modest; if cost becomes an issue, raise tick_every to 300
# (5min) — still beats the 4-day blackout we just lived through.
# -----------------------------------------------------------------------------
resource "datadog_synthetics_test" "llm_inference_health" {
  for_each = local.llm_inference_synthetic_endpoints

  type    = "api"
  subtype = "http"
  status  = "live"
  name    = "[${upper(var.environment)}] LLM Inference /health — ${each.key} (Managed by Terraform)"
  tags    = concat(local.llm_inference_monitor_tags, ["endpoint:${each.key}"])
  message = <<-EOT
    ## LLM Inference /health Check Failing — ${each.key}

    External `GET ${each.value}` failed for at least 3 consecutive minutes.
    This is a user-perspective signal: every request reaching this hostname is
    affected, regardless of the underlying cause (k8s pod, NEG, LB, DNS, cert).

    ### Triage
    1. Curl directly to confirm:
       `curl -s -o /dev/null -w "%%{http_code} %%{time_total}s\n" --max-time 10 ${each.value}`
    2. If 5xx: check pod state — `kubectl get pods -n apps-llm-ns | grep ${each.key}`
    3. If timeout / connection refused: check GCP load balancer + NEG health.
    4. If 4xx: usually cert / routing rule changed; inspect Ingress + ManagedCertificate.

    ${local.llm_inference_escalation_message}
  EOT

  request_definition {
    method  = "GET"
    url     = each.value
    timeout = 10
  }

  request_headers = {
    "User-Agent" = "Datadog-Synthetic-LLMInference/1.0"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  # No responseTime assertion: /health proxies through `deep_health_check.py`
  # which performs a real chat completion on the local vLLM instance, so
  # legitimate latency varies 0.4s–5s+ depending on warm-up state. Latency
  # degradation is already tracked by the vllm_e2e_request_latency_seconds
  # monitors. This synthetic targets availability only.

  # Single location keeps cost minimal; us-east-1 chosen because it's distinct
  # from both inference regions (us-central1, us-west1) so a regional GCP
  # outage doesn't simultaneously break the probe and the service.
  locations = ["aws:us-east-1"]

  options_list {
    tick_every           = 60
    follow_redirects     = false
    min_failure_duration = 180 # alert after 3m sustained failure
    min_location_failed  = 1

    retry {
      count    = 2
      interval = 1000
    }

    monitor_options {
      renotify_interval = 30
    }

    monitor_priority = 1
  }
}
