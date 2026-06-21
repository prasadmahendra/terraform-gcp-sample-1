# # roles/billing.costsManager
# resource "google_organization_iam_member" "organization_iam_binding_for_infra_engineers_billing_costs_manager_for_prod" {
#   org_id = var.org_id
#   role   = "roles/billing.costsManager"
#   member = local.gsuite_infra_engineers_group_id
# }

resource "google_billing_account_iam_member" "billing_user" {
  billing_account_id = local.billing_account_id
  role               = "roles/billing.costsManager"
  member             = local.gsuite_infra_engineers_group_id
}

resource "google_billing_account_iam_member" "billing_user_for_bi_analysts" {
  billing_account_id = local.billing_account_id
  role   = "roles/billing.costsManager"
  member = local.gsuite_bi_analysts_group_id
}