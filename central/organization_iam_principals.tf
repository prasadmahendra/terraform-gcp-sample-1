locals {
  bi_analysts_role_related_properties = {
    cdp_streams_bigtable_instance_id     = "cdp-streams"
    cdp_streams_bigtable_events_table_id = ""
    dev_project_number                   = data.terraform_remote_state.dev.outputs.project_number
    prod_project_number                  = data.terraform_remote_state.prod.outputs.project_number
    spiffy_bi_configs_bucket_name        = "spiffy-bi-configs-prod"
  }
  backend_engineers_role_related_properties = {
    dev_project_number  = data.terraform_remote_state.dev.outputs.project_number
    dev_project_id      = data.terraform_remote_state.dev.outputs.project_id
    prod_project_number = data.terraform_remote_state.prod.outputs.project_number
    prod_project_id     = data.terraform_remote_state.prod.outputs.project_id
  }
  gsuite_backend_engineers_group_id    = "group:${google_cloud_identity_group.cloud_identity_group_backend_engineers.group_key[0].id}"
  gsuite_deployment_engineers_group_id = "group:${google_cloud_identity_group.cloud_identity_group_deployment_engineers.group_key[0].id}"
  gsuite_infra_engineers_group_id      = "group:${google_cloud_identity_group.cloud_identity_group_infra_engineers.group_key[0].id}"
  gsuite_qa_engineers_group_id         = "group:${google_cloud_identity_group.cloud_identity_group_qa_engineers.group_key[0].id}"
  gsuite_bi_analysts_group_id          = "group:${google_cloud_identity_group.cloud_identity_group_bi_analyst.group_key[0].id}"
  gsuite_security_reviewers_group_id   = "group:${google_cloud_identity_group.cloud_identity_group_security_reviewers.group_key[0].id}"
  gsuite_ml_engineers_group_id         = "group:${google_cloud_identity_group.cloud_identity_group_ml_engineers.group_key[0].id}"
}

# Example to add by email address (where local.bi_analysts is a list of email addresses)
# resource "google_cloud_identity_group_membership" "cloud_identity_group_membership_for_bi_analysts" {
#   for_each = toset(local.bi_analysts)
#   group    = google_cloud_identity_group.cloud_identity_group_bi_analyst.id
#   preferred_member_key {
#     id = each.value
#   }
#   roles {
#     name = "MEMBER"
#   }
# }
