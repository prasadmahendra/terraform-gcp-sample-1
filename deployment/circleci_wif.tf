# Workload Identity Federation for CircleCI
#
# Adds a CircleCI OIDC provider to the existing "github-actions" WIF pool so
# that CircleCI jobs can authenticate to GCP keylessly — the same pattern used
# for GitHub Actions in github_actions_wif.tf.
#
# How it works:
#   1. Each CircleCI job automatically receives a signed OIDC token ($CIRCLE_OIDC_TOKEN).
#   2. The token is exchanged for a short-lived GCP access token via the WIF STS endpoint.
#   3. The WIF provider validates the token issuer (oidc.circleci.com) and restricts
#      access to tokens issued for the specific CircleCI project.
#   4. The token is impersonated as the existing `github-actions-tf-plan` service account.
#
# After applying, set these variables in the CircleCI "terraform" context:
#   CCI_WIF_PROVIDER_DEV   = output.circleci_wif_provider  (from dev apply)
#   CCI_WIF_PROVIDER_PROD  = output.circleci_wif_provider  (from prod apply)
#   SA_EMAIL_DEV           = output.github_actions_tf_plan_sa_email  (same as Actions)
#   SA_EMAIL_PROD          = same
#
# For the central project, apply a similar block in central/ or create
# a matching google_iam_workload_identity_pool_provider there.
#
# Required variable values (add to environments/<env>/terraform.tfvars):
#   circleci_org_id     — found at CircleCI → Organization Settings → Overview
#   circleci_project_id — found at CircleCI → Project Settings → Overview
#
# Resources are conditional on `circleci_org_id` being non-empty so that
# existing deployments are not broken before these variables are set.

# ── OIDC provider for CircleCI ─────────────────────────────────────────────
resource "google_iam_workload_identity_pool_provider" "circleci" {
  count = var.circleci_org_id != "" ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "circleci"
  display_name                       = "CircleCI OIDC"
  description                        = "WIF provider for CircleCI OIDC tokens (terraform CI)"
  project                            = google_project.deployment-project.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.project_id" = "assertion['oidc.circleci.com/project-id']"
    "attribute.org_id"     = "assertion.aud"
  }

  # If circleci_project_id is provided, restrict to that project only.
  # Otherwise, any project in the org can authenticate (still org-scoped via allowed_audiences).
  # Set circleci_project_id in terraform.tfvars to tighten this once you have the UUID
  # (Project Settings → Overview, or via: curl https://circleci.com/api/v2/project/gh/<org>/<repo> -H "Circle-Token: <token>")
  attribute_condition = var.circleci_project_id != "" ? "attribute.project_id == \"${var.circleci_project_id}\"" : null

  oidc {
    # Issuer URL is org-scoped in CircleCI.
    issuer_uri        = "https://oidc.circleci.com/org/${var.circleci_org_id}"
    # The audience in CircleCI OIDC tokens is the org ID.
    allowed_audiences = [var.circleci_org_id]
  }
}

# ── Allow CircleCI tokens to impersonate the TF plan service account ────────
# Re-uses the existing `github-actions-tf-plan` SA so no extra IAM bindings are
# needed for project-level roles — the SA already has viewer, secretAccessor, etc.
resource "google_service_account_iam_member" "circleci_tf_plan_wif" {
  count = var.circleci_org_id != "" ? 1 : 0

  service_account_id = google_service_account.github_actions_tf_plan.name
  role               = "roles/iam.workloadIdentityUser"
  # If project ID is known, scope to that project; otherwise scope to entire org.
  member = var.circleci_project_id != "" ? (
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.project_id/${var.circleci_project_id}"
    ) : (
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.org_id/${var.circleci_org_id}"
  )
}

# ── Output — set this as CCI_WIF_PROVIDER_DEV / CCI_WIF_PROVIDER_PROD ───────
output "circleci_wif_provider" {
  description = "WIF provider resource name — set as CCI_WIF_PROVIDER_DEV or CCI_WIF_PROVIDER_PROD in the CircleCI 'terraform' context"
  value       = var.circleci_org_id != "" ? google_iam_workload_identity_pool_provider.circleci[0].name : null
}
