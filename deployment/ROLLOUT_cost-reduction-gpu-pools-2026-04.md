# Rollout & Rollback — `infra/cost-reduction-gpu-pools-2026-04`

> Branch: `infra/cost-reduction-gpu-pools-2026-04`
> Owner: rhurtado-art
> Created: 2026-04-24
> Total expected immediate savings: **~$2.3k/mo** (plus ~$12k/mo unlocked as follow-up)

This PR is structured as **4 independent commits**. Each one is self-contained and can be applied, observed, or reverted on its own. Recommended sequence: land commits in order, soak ~24h between the medium-risk ones.

---

## At-a-glance

| # | Commit | Module | Risk | Direct $/mo | Live blast radius |
|---|--------|--------|------|-------------|-------------------|
| 1 | `3fda698` | `services.tf` — us-central1 `llama-3-8b` | low | ~$1.7k | 1 A100 freed, node stays (cdc-main-db) |
| 2 | `6a43da0` | `gke_cluster_default_region.tf` — calmode pool | none | $0 | TF-only; pool already had 0 running nodes |
| 3 | `035ea00` | `services.tf` — us-west1 `llama-3-70b-qtz` | low | $0 (unlocks ~$12k follow-up) | Headroom on 8×H100 node |
| 4 | `56de36e` | `services.tf` — prod `textembed-default` | medium | ~$600 | 1 NAP L4 node freed |

All changes are **reversible by `git revert <sha>` + `terraform apply`**.

---

## Pre-flight checks (run once before any apply)

```bash
# 1. Auth
gcloud auth login
gcloud config set project spiffy-prod
gcloud container clusters get-credentials gke-default --region us-central1
gcloud container clusters get-credentials gke-us-west1 --region us-west1

# 2. Capture baseline metrics (pin to a Datadog dashboard snapshot or screenshot)
#    - p50/p95/p99 latency on:
#        inference.llama-3-8b-usc1
#        inference.llama-3-70b-qtz-usw1
#        textembed-default
#    - vLLM KV cache % per pod
#    - 5xx rate per service

# 3. Snapshot current replica counts
kubectl -n apps-llm-ns get deploy -o wide | tee /tmp/baseline-llm-ns.txt
kubectl -n apps-textembed-ns get deploy -o wide | tee /tmp/baseline-textembed.txt

# 4. Confirm workspace is clean
cd terraform/deployment && terraform plan -lock=false -detailed-exitcode
#    Exit code 0 = no drift, 2 = drift to review (do NOT proceed if 2 with unrelated changes).
```

---

## Module 1 — us-central1 `llama-3-8b` 2 → 1 replica (`3fda698`)

**File:** `deployment/services.tf` (block `service_name_suffix = "llama-3-8b-usc1"`)

### Why
- vLLM KV cache peaks at **0.7%** with 2 replicas; never queues.
- us-west1 has 2 replicas as cross-region fallback.

### Apply
```bash
git checkout infra/cost-reduction-gpu-pools-2026-04
git rebase --onto main main~ 3fda698   # if cherry-picking; otherwise just push
cd terraform/deployment
terraform plan -target=module.llm-inference-svc-default-region
terraform apply -target=module.llm-inference-svc-default-region
```

### Verify (within 30 min)
```bash
kubectl -n apps-llm-ns get deploy -l app=llm-inference-svc-llama-3-8b-usc1
# Expect: READY 1/1
```
- Datadog: p95 latency for `llama-3-8b-usc1` should stay within +20% of baseline.
- vLLM KV cache should stay <50% (was 0.7% before; even 5–10× growth is safe).

### Rollback
```bash
git revert 3fda698
git push
# After PR merges:
cd terraform/deployment
terraform apply -target=module.llm-inference-svc-default-region
```
Recovery time: ~3–5 min for new pod to schedule + warm vLLM (model weights cached on node SSD).

### Failure signals
- p95 > 2× baseline sustained 10 min → rollback.
- Sustained `Waiting > 0` in vLLM metrics → rollback.
- HPA-related events / OOM → rollback.

---

## Module 2 — Park `a3-highgpu-8g-calmode-pool` (`6a43da0`)

**File:** `deployment/gke_cluster_default_region.tf`

### Why
- Reservation `bfcm-surge-a3-highgpu-8g-2025-1-us-central1-c-3` was deleted (gcloud 404).
- Pool had `total_min=1` but couldn't actually provision → silent TF drift.
- Zero pods target this pool today.

### Apply
```bash
cd terraform/deployment
terraform plan -target=module.container-cluster-default-a3-highgpu-8g-calmode-pool
terraform apply -target=module.container-cluster-default-a3-highgpu-8g-calmode-pool
```
Expected plan: in-place update (autoscaling 1→0, 2→0; remove `reservation_affinity`).

### Verify
```bash
gcloud container node-pools describe a3-highgpu-8g-calmode-pool \
  --cluster=gke-default --region=us-central1 --project=spiffy-prod \
  --format="value(autoscaling.minNodeCount,autoscaling.maxNodeCount)"
# Expect: 0  0
```

### Rollback
Restore by reverting the commit AND procuring a fresh calendar reservation. Revert alone will re-introduce the pinning to the deleted reservation and `terraform apply` will fail. Steps:
1. Procure new reservation, capture its name.
2. `git revert 6a43da0`
3. Edit the restored file, swap reservation name to the new one.
4. `terraform apply -target=...calmode-pool`

Recovery time: depends on reservation procurement (hours–days). **No production impact from leaving it parked.**

### Failure signals
- BFCM/peak-event traffic returning before this pool is restored → out of scope of this PR; coordinate with infra to procure a new calendar block.

---

## Module 3 — us-west1 `llama-3-70b-qtz` 3 → 2 replicas (`035ea00`)

**File:** `deployment/services.tf` (block `service_name_suffix = "llama-3-70b-qtz-usw1"`)

### Why
- KV cache 0.1–4.8% across all 3 replicas; mostly idle.
- Direct $0 (the 8×H100 node stays up serving the other replicas), but **frees 2 H100s of headroom**, unlocking the follow-up downsize to `a3-highgpu-4g` (~$12k/mo).

### Apply
```bash
cd terraform/deployment
terraform plan -target=module.llm-inference-svc-secondary-region
terraform apply -target=module.llm-inference-svc-secondary-region
```

### Verify (soak 24–48h before next module)
- Datadog: `llama-3-70b-qtz-usw1` p95/p99 within +30% of baseline.
- KV cache % may roughly 1.5× — still must stay <50%.
- us-central1 flex-start `a3-highgpu-2g-flex-pool` available as spot-capacity fallback.

### Rollback
```bash
git revert 035ea00
terraform apply -target=module.llm-inference-svc-secondary-region
```
Recovery time: ~5–10 min (70b weights are large; node SSD cache helps).

### Failure signals
- p99 latency > 2× baseline → rollback.
- KV cache > 60% sustained → rollback (real saturation risk).
- Cross-region failover from us-central1 spot-capacity firing repeatedly → rollback.

---

## Module 4 — prod `textembed-default` 2 → 1 replica (`56de36e`)

**File:** `deployment/services.tf`

### Why
- Each replica lands on its own NAP `g2-standard-8` (1×L4) → dropping to 1 frees one full node (~$600/mo).
- `textembed-search-idx-default` (separate variant) is **unchanged**.

### Apply
```bash
cd terraform/deployment
terraform plan -target=module.textembed-services-default-region
terraform apply -target=module.textembed-services-default-region
```

### Verify
```bash
kubectl -n apps-textembed-ns get deploy textembed-default -o wide
# Expect: READY 1/1
```
- Datadog: `textembed-default` p95 within +25% of baseline.
- Confirm one NAP `g2-standard-8` node drains and is removed by autoscaler within ~15 min.

### Rollback
```bash
git revert 56de36e
terraform apply -target=module.textembed-services-default-region
```
Recovery time: ~5–8 min (NAP must provision a new L4 node + pull image + warm model).

### Failure signals (medium-risk module)
- p95 > 2× baseline sustained 5 min → rollback.
- Embedding queue depth growing unbounded upstream → rollback.
- HPA can't scale (single replica is the floor here) → rollback.

---

## Full-PR rollback (nuclear option)

If multiple modules misbehave and surgical revert is too slow:

```bash
# Identify the merge commit on main (after merge)
MERGE_SHA=$(git log --merges --grep="cost-reduction-gpu-pools-2026-04" -1 --format=%H)

git revert -m 1 $MERGE_SHA
git push origin main
cd terraform/deployment
terraform plan
terraform apply
```
ETA to fully restored capacity: **~10–15 min** (longest path = 70b-qtz pod warmup).

---

## Post-merge follow-ups (NOT in this PR)

These are unlocked by the changes here. Track separately.

1. **us-west1 `a3-highgpu-8g` → `a3-highgpu-4g` downsize** — ~$12k/mo. Soak this PR ~1 week first.
2. **us-central1 a2-ultragpu-2g elimination** — ~$3.5k/mo. Requires moving `cdc-main-db` (singleton) off the A100 node.
3. **us-central1 70b-qtz flex-start → 0 replicas** — ~$7k/mo on flex billing. Only after Module 3 has soaked at 2 replicas in west1 for ~1 week.

---

## Decision log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-24 | Branch created with 4 commits | Single PR, modular commits, no force pushes |
| 2026-04-27 | DRA / GPU sharing rejected | vLLM PagedAttention incompatible; GKE on 1.34, DRA-stable needs ~1.36+ |
| 2026-04-27 | Central1 70b-qtz pause deferred | Land this PR first, soak west1 at 2 replicas for ~1 week |
