#!/usr/bin/env bash
# =============================================================================
# diagnose-llm.sh — first-pass triage for LLM inference services
# =============================================================================
#
# Codifies the diagnostic chain we walked manually during the 2026-04-29
# incident (canary crash-looped 4d23h on local-SSD ENOSPC, no page fired).
# Run when a Datadog monitor fires for an llm-inference-svc-* deployment to
# get a single structured report that points at the failure mode.
#
# Usage:
#   ./diagnose-llm.sh <service-suffix>
#
# Examples:
#   ./diagnose-llm.sh qtz-usc1              # quantized 70B canary, us-central1
#   ./diagnose-llm.sh qtz-usw1              # quantized 70B prod, us-west1
#   ./diagnose-llm.sh llama-3-8b-usc1       # 8B model, us-central1
#
# Requires: kubectl, gcloud, curl, jq (optional, for JSON formatting).
# Cluster auth (run once if not already):
#   gcloud container clusters get-credentials gke-default     --region us-central1 --project spiffy-prod
#   gcloud container clusters get-credentials gke-us-west1    --region us-west1    --project spiffy-prod
#
# This script is read-only. No mutation. Safe to run on prod.
# =============================================================================

set -uo pipefail

# Color helpers (TTY only)
if [ -t 1 ]; then
  RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; BLU='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; YEL=''; GRN=''; BLU=''; BOLD=''; NC=''
fi

section() { printf "\n${BOLD}${BLU}=== %s ===${NC}\n" "$1"; }
ok()      { printf "${GRN}%s${NC}\n" "$1"; }
warn()    { printf "${YEL}%s${NC}\n" "$1"; }
err()     { printf "${RED}%s${NC}\n" "$1"; }

# --- Argument parsing --------------------------------------------------------

if [ "$#" -lt 1 ]; then
  err "Missing service suffix."
  echo "Usage: $0 <service-suffix>   e.g. qtz-usc1, qtz-usw1, llama-3-8b-usc1"
  exit 2
fi

SUFFIX="$1"
SERVICE="llm-inference-svc-llama-3-70b-${SUFFIX}"
NS="apps-llm-ns"

# Map region suffix → cluster context. usc1/use1/usc/use → default cluster.
# usw1 → us-west1 cluster. Add new regions here as services come online.
case "$SUFFIX" in
  *usc1|*use1|*usc|*use) CTX="gke_spiffy-prod_us-central1_gke-default" ;;
  *usw1)                 CTX="gke_spiffy-prod_us-west1_gke-us-west1"   ;;
  *) err "Unknown region in suffix '$SUFFIX'. Update region map in $0."; exit 2 ;;
esac

# Public hostname follows a fixed pattern; not all services match it (e.g. l4),
# but covers the common cases we triage on-call.
LB_HOST="inference-${SERVICE#llm-inference-svc-}.spiffy.ai"
LB_HOST="${LB_HOST/llama-3-70b-/llama-3-70b-}"

cat <<EOF
${BOLD}LLM Inference Diagnose${NC}
service:   $SERVICE
namespace: $NS
context:   $CTX
lb host:   https://$LB_HOST
time:      $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# --- (1) Pod state -----------------------------------------------------------

section "1. Pod state"
PODS_JSON=$(kubectl --context="$CTX" get pods -n "$NS" -o json 2>/dev/null \
  | jq -c --arg svc "$SERVICE" '.items[] | select(.metadata.labels.app == $svc)' 2>/dev/null)

if [ -z "$PODS_JSON" ]; then
  err "No pods found with label app=$SERVICE in namespace $NS."
  echo "Possible causes:"
  echo "  - Service suffix wrong (check kubectl --context=$CTX get pods -n $NS | grep <suffix>)"
  echo "  - Deployment not yet rolled out"
  echo "  - Cluster auth expired (run gcloud container clusters get-credentials ...)"
  exit 1
fi

echo "$PODS_JSON" | jq -r '
  [.metadata.name,
   .status.phase,
   ([.status.containerStatuses[]? | "\(.ready)"] | join("/")),
   ([.status.containerStatuses[]? | .restartCount] | add // 0 | tostring),
   .spec.nodeName // "(unscheduled)",
   ((now - (.metadata.creationTimestamp | fromdate))/60 | floor | tostring + "m")
  ] | @tsv' \
  | awk 'BEGIN { printf "%-70s %-10s %-8s %-8s %-60s %s\n", "POD", "PHASE", "READY", "RESTARTS", "NODE", "AGE" }
         { printf "%-70s %-10s %-8s %-8s %-60s %s\n", $1, $2, $3, $4, $5, $6 }'

PODS_COUNT=$(echo "$PODS_JSON" | wc -l)
READY_COUNT=$(echo "$PODS_JSON" | jq -s '[.[] | select(all(.status.containerStatuses[]?; .ready == true))] | length')

if [ "$READY_COUNT" -eq 0 ]; then
  err "Zero pods Ready. Users seeing 502s. Continue diagnosis."
elif [ "$READY_COUNT" -lt "$PODS_COUNT" ]; then
  warn "Some pods not Ready ($READY_COUNT/$PODS_COUNT). Partial degradation."
else
  ok "All $PODS_COUNT pod(s) Ready."
fi

# Operate on the first non-Running or first pod for log tailing
TARGET_POD=$(echo "$PODS_JSON" | jq -rs '
  (map(select(.status.phase != "Running")) | first | .metadata.name) //
  (.[0].metadata.name)')
TARGET_NODE=$(echo "$PODS_JSON" | jq -rs --arg p "$TARGET_POD" '.[] | select(.metadata.name == $p) | .spec.nodeName // ""')

# --- (2) Pod events (recent) -------------------------------------------------

section "2. Recent events on $TARGET_POD"
kubectl --context="$CTX" describe pod -n "$NS" "$TARGET_POD" 2>/dev/null \
  | sed -n '/Events:/,$p' | tail -n 20

# --- (3) Main container logs (current + previous) ----------------------------

section "3. Main container logs (last 30 lines, current)"
kubectl --context="$CTX" logs -n "$NS" "$TARGET_POD" -c "$SERVICE" --tail=30 2>&1 | tail -30

section "3b. Main container logs (last 30 lines, --previous attempt)"
kubectl --context="$CTX" logs -n "$NS" "$TARGET_POD" -c "$SERVICE" --tail=30 --previous 2>&1 | tail -30

# --- (4) Node + capacity -----------------------------------------------------

section "4. Node + GPU capacity"
if [ -n "$TARGET_NODE" ]; then
  echo "Pod node: $TARGET_NODE"
  kubectl --context="$CTX" get node "$TARGET_NODE" -o jsonpath='accelerator={.metadata.labels.cloud\.google\.com/gke-accelerator} compute-class={.metadata.labels.cloud\.google\.com/compute-class} schedulable={.spec.unschedulable} taints={.spec.taints}{"\n"}' 2>&1
  printf "\nNode conditions:\n"
  kubectl --context="$CTX" get node "$TARGET_NODE" -o jsonpath='{range .status.conditions[?(@.status=="True")]}  {.type}{"\n"}{end}' 2>&1
  printf "\nEphemeral storage capacity (note: /mnt/stateful_partition is a slice of this):\n"
  kubectl --context="$CTX" get node "$TARGET_NODE" -o jsonpath='  capacity={.status.capacity.ephemeral-storage}  allocatable={.status.allocatable.ephemeral-storage}{"\n"}' 2>&1
else
  warn "Pod has no node assigned (still Pending). Check scheduling events above."
fi

echo ""
echo "Cluster H100 node count (expected for qtz-* services):"
H100=$(kubectl --context="$CTX" get nodes -l 'cloud.google.com/gke-accelerator=nvidia-h100-80gb' --no-headers 2>/dev/null | wc -l)
echo "  $H100 node(s)"
[ "$H100" -eq 0 ] && warn "No H100 nodes currently. NAP fallback to A100 likely. Check FailedScaleUp events for capacity stockout."

# --- (5) Recent autoscaler / scheduling events for this pod ------------------

section "5. Cluster autoscaler / scheduling events (last 6 for this pod)"
kubectl --context="$CTX" get events -n "$NS" --field-selector "involvedObject.name=$TARGET_POD" --sort-by='.lastTimestamp' 2>/dev/null \
  | tail -7

# --- (6) Public LB endpoint health ------------------------------------------

section "6. Public LB endpoint health"
for path in "/health" "/v1/models"; do
  printf "  %-15s " "$path"
  curl -s -o /dev/null -w "status=%{http_code} total=%{time_total}s\n" --max-time 10 "https://$LB_HOST$path" 2>&1
done

printf "  %-15s " "/metrics"
curl -s -o /dev/null -w "status=%{http_code} total=%{time_total}s size=%{size_download}\n" --max-time 30 "https://$LB_HOST/metrics" 2>&1

# --- (7) GCP backend service health -----------------------------------------

section "7. GCP load balancer backend health"
BS=$(gcloud compute backend-services list --project=spiffy-prod \
  --filter="name~'$SERVICE'" --format="value(name)" 2>/dev/null | head -1)

if [ -z "$BS" ]; then
  # Fallback: GKE auto-generated backend with k8s1- prefix
  BS=$(gcloud compute backend-services list --project=spiffy-prod \
    --format="value(name)" 2>/dev/null \
    | grep -E "k8s1-.*${SUFFIX//-/.}.*" | head -1)
fi

if [ -n "$BS" ]; then
  echo "Backend service: $BS"
  gcloud compute backend-services get-health "$BS" --global --project=spiffy-prod 2>&1 \
    | grep -E "healthState|instance:|ipAddress:" | head -20
else
  warn "Could not auto-resolve backend service. Run manually:"
  echo "  gcloud compute backend-services list --project=spiffy-prod | grep -i $SUFFIX"
fi

# --- (8) Quick disk-fill check (manual command) ------------------------------

section "8. Local-SSD orphan check (run separately if pod has restarts)"
if [ -n "$TARGET_NODE" ]; then
  cat <<EOF
The 2026-04-29 incident root cause was orphan tempdirs filling
/mnt/stateful_partition. To confirm/clean on this node, run:

  kubectl --context=$CTX debug node/$TARGET_NODE -it \\
    --image=busybox --profile=sysadmin -- \\
    sh -c 'df -h /host/mnt/stateful_partition && \\
           du -sh /host/mnt/stateful_partition/data/ssd/copy-* 2>/dev/null | sort -h | tail -5'

To clean (non-destructive to running pods, only removes tempdirs):

  kubectl --context=$CTX debug node/$TARGET_NODE -it \\
    --image=busybox --profile=sysadmin -- \\
    sh -c 'rm -rf /host/mnt/stateful_partition/data/ssd/copy-*'
EOF
fi

# --- (9) Useful Datadog links ------------------------------------------------

section "9. Datadog quick links"
DD="https://us5.datadoghq.com"
cat <<EOF
Dashboards:
  Inference Services    $DD/dashboard/c7k-vjf-iq3
  vLLM Overview         $DD/dashboard/1081
  Inference performance $DD/dashboard/pw3-vxu-vry

Logs (filtered to this service, past 30m):
  $DD/logs?query=service%3A$SERVICE&from_ts=$(($(date +%s)*1000 - 1800000))&to_ts=$(($(date +%s)*1000))

Events (k8s events for this service, past 1h):
  $DD/event/explorer?query=$SERVICE+source%3Akubernetes&from=$(($(date +%s) - 3600))000&to=$(($(date +%s)))000
EOF

section "Done"
