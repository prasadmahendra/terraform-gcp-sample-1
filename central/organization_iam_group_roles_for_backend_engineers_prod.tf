# cloudsql access - roles/cloudsql.client
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloudsql_client_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/cloudsql.client"
  member = local.gsuite_backend_engineers_group_id
}

# cloudsql access - roles/cloudsql.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloudsql_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/cloudsql.viewer"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_secrets_manager_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/secretmanager.viewer"
  member = local.gsuite_backend_engineers_group_id
}

# cloud run/cloud job viewer role
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloud_run_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/run.viewer"
  member = local.gsuite_backend_engineers_group_id
}

# roles/run.sourceViewer
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_run_source_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/run.sourceViewer"
  member = local.gsuite_backend_engineers_group_id
}

# datastore access read only
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_datastore_access_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/datastore.viewer"
  member = local.gsuite_backend_engineers_group_id
}

# roles/logging.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_logging_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/logging.viewer"
  member = local.gsuite_backend_engineers_group_id
}

# roles/monitoring.viewer
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_monitoring_viewer_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = "roles/monitoring.viewer"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_artifact_registry_writer_for_prod_to_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id # artifact registry is in prod
  role   = "roles/artifactregistry.reader" # Must be R/O access. Only CI/CD is allowed to push
  member = local.gsuite_backend_engineers_group_id
}

# Read-only GCS access. Write/delete are intentionally excluded for prod.
resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_gcs_access_for_prod" {
  role_id     = "spiffy.BackendEngineersRoleGcsAccessProd"
  org_id      = var.org_id
  title       = "Backend Engineers Role - GCS Access [PROD]"
  description = "Terraform Managed - Role for Backend Engineers - GCS Read-Only Access [PROD]"
  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_gcs_access_unrestricted_for_prod" {
  role_id     = "spiffy.BackendEngineersRoleGcsUnrestrictedAccessProd"
  org_id      = var.org_id
  title       = "Backend Engineers Role - GCS Unrestricted Access [PROD]"
  description = "Terraform Managed - Role for Backend Engineers - GCS Unrestricted Bucket List [PROD]"
  permissions = [
    "storage.buckets.list",
  ]
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_gcs_access_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_gcs_access_for_prod.id
  member = local.gsuite_backend_engineers_group_id

  condition {
    title       = "Allow GCS read-only access for Backend Engineers [PROD]"
    description = "Terraform Managed - Allow GCS read-only access for Backend Engineers [PROD]"
    # Don't allow spiffy-tfstate bucket access for backend engineers
    expression  = <<EXPR
!resource.name.startsWith("projects/_/buckets/spiffy-tfstate")
EXPR
  }
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_gcs_unrestricted_access_for_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_gcs_access_unrestricted_for_prod.id
  member = local.gsuite_backend_engineers_group_id
}
