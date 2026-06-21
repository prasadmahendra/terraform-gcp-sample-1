resource "google_organization_iam_custom_role" "org_role_for_bi_analyst_bigtable_access" {
  role_id = "spiffy.BiAnalystRoleBigTableAccess"
  org_id  = var.org_id
  title   = "BI Analyst Role - BigTable Access"
  description = "Terraform Managed - Role for BI Analyst - BigTable Access"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = concat(
    [
      "bigtable.tables.readRows",
      "bigtable.tables.get",
      "bigtable.tables.list",
      "bigtable.instances.get",
      "bigtable.instances.list",
      "bigtable.instances.ping",
      "bigtable.clusters.get",
      "bigtable.clusters.list",
    ]
  )
}

resource "google_organization_iam_custom_role" "org_role_for_bi_analyst_gcs_access" {
  role_id = "spiffy.BiAnalystRoleGcsAccess"
  org_id  = var.org_id
  title   = "BI Analyst Role - GCS Access"
  description = "Terraform Managed - Role for BI Analyst - GCS Access"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = concat(
    [
      "storage.buckets.get",
      "storage.buckets.list",
      "storage.objects.get",
      "storage.objects.list",
    ]
  )
}

resource "google_folder_iam_member" "organization_iam_binding_for_bi_analyst_bigtable_access" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = google_organization_iam_custom_role.org_role_for_bi_analyst_bigtable_access.id
  member = local.gsuite_bi_analysts_group_id
  condition {
    title       = "Allow big-table access for BI analysts"
    description = "Terraform Managed - Allow big-table access for BI analysts"
    expression  = <<EXPR
resource.name.startsWith("projects/${local.bi_analysts_role_related_properties.prod_project_number}/instances/${local.bi_analysts_role_related_properties.cdp_streams_bigtable_instance_id}/tables/${local.bi_analysts_role_related_properties.cdp_streams_bigtable_events_table_id}")
EXPR
  }
}

resource "google_folder_iam_member" "organization_iam_binding_for_bi_analyst_gcs_access" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = google_organization_iam_custom_role.org_role_for_bi_analyst_gcs_access.id
  member = local.gsuite_bi_analysts_group_id

  condition {
    title       = "Allow GCS access for BI analysts"
    description = "Terraform Managed - Allow GCS access for BI analysts"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${local.bi_analysts_role_related_properties.spiffy_bi_configs_bucket_name}")
EXPR
  }
}

# big query read access for BI analysts
# roles/bigquery.dataViewer
resource "google_folder_iam_member" "organization_iam_binding_for_bi_analyst_bigquery_data_viewer" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/bigquery.dataViewer"
  member = local.gsuite_bi_analysts_group_id
}

# roles/bigquery.jobUser
resource "google_folder_iam_member" "organization_iam_binding_for_bi_analyst_bigquery_job_user" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/bigquery.jobUser"
  member = local.gsuite_bi_analysts_group_id
}