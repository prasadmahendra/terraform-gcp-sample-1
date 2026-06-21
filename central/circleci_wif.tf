# Workload Identity Federation for CircleCI
#
# Adds a CircleCI OIDC provider to the existing "github-actions" WIF pool so
# that CircleCI jobs can authenticate to GCP keylessly — mirrors the pattern
# in deployment/circleci_wif.tf.
#
# After applying, set this variable in the CircleCI "terraform" context:
#   CCI_WIF_PROVIDER_CENTRAL = output.circleci_wif_provider
#
# Required variable values (add to central/terraform.tfvars):
#   circleci_org_id     — CircleCI Organization ID (UUID)
#   circleci_project_id — CircleCI project ID (optional; tightens WIF to one project)

resource "google_iam_workload_identity_pool_provider" "circleci" {
  count = var.circleci_org_id != "" ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "circleci"
  display_name                       = "CircleCI OIDC"
  description                        = "WIF provider for CircleCI OIDC tokens (terraform CI)"
  project                            = google_project.deployment-central.project_id

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.project_id" = "assertion['oidc.circleci.com/project-id']"
    "attribute.org_id"     = "assertion.aud"
  }

  # If circleci_project_id is provided, restrict to that project only.
  # Otherwise, any project in the org can authenticate (still org-scoped via allowed_audiences).
  attribute_condition = var.circleci_project_id != "" ? "attribute.project_id == \"${var.circleci_project_id}\"" : null

  oidc {
    issuer_uri        = "https://oidc.circleci.com/org/${var.circleci_org_id}"
    allowed_audiences = [var.circleci_org_id]
  }
}

resource "google_service_account_iam_member" "circleci_tf_plan_wif" {
  count = var.circleci_org_id != "" ? 1 : 0

  service_account_id = google_service_account.github_actions_tf_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member = var.circleci_project_id != "" ? (
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.project_id/${var.circleci_project_id}"
    ) : (
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.org_id/${var.circleci_org_id}"
  )
}

output "circleci_wif_provider" {
  description = "WIF provider resource name — set as CCI_WIF_PROVIDER_CENTRAL in the CircleCI 'terraform' context"
  value       = var.circleci_org_id != "" ? google_iam_workload_identity_pool_provider.circleci[0].name : null
}
