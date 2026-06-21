locals {
  identity_pool_id          = "vanta-9adcc40747bf876"
  subject_name              = "vanta-scanner"
  aws_role_name             = "scanner"
  identity_provider_id      = "vanta-aws"
  vanta_scanner_subject_uri = "principal://iam.googleapis.com/projects/${google_project.deployment-central.number}/locations/global/workloadIdentityPools/${local.identity_pool_id}/subject/${local.subject_name}"
}

# Creates the VantaExtensiveOrganizationScanner role
resource "google_organization_iam_custom_role" "vanta_org_scanner_role" {
  depends_on = [
    google_project_service.all
  ]
  org_id      = var.org_id
  role_id     = "VantaExtensiveOrganizationScanner"
  title       = "Vanta Extensive Organization Scanner"
  description = "Role for listing inherited IAM policies"
  permissions = [
    "iam.roles.list",
    "resourcemanager.organizations.getIamPolicy",
    "resourcemanager.folders.getIamPolicy",
    "resourcemanager.projects.get",
    "resourcemanager.projects.list",
    "resourcemanager.folders.list",
    "bigquery.datasets.get",
    "compute.instances.get",
    "compute.instances.getEffectiveFirewalls",
    "compute.subnetworks.get",
    "pubsub.topics.get",
    "storage.buckets.get",
    "cloudasset.assets.searchAllResources",
  ]
}

# Create the Workload Identity Pool
resource "google_iam_workload_identity_pool" "vanta_identity_pool" {
  depends_on = [
    google_project_service.all
  ]
  project                   = google_project.deployment-central.project_id
  workload_identity_pool_id = local.identity_pool_id
  display_name              = "Vanta"
}

# Wait for the pool to be created
resource "time_sleep" "wait_for_vanta_scanner_pool_creation" {
  depends_on = [google_iam_workload_identity_pool.vanta_identity_pool]
  create_duration = "30s"
}

# Create the Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "vanta_identity_provider" {
  depends_on = [time_sleep.wait_for_vanta_scanner_pool_creation]
  project                            = google_project.deployment-central.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.vanta_identity_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = local.identity_provider_id
  display_name                       = "Vanta AWS"

  attribute_mapping = {
    "google.subject" = "'${local.subject_name}'"
    "attribute.arn"  = "assertion.arn"
  }
  attribute_condition = "attribute.arn.extract('assumed-role/{role}/') == '${local.aws_role_name}'"
  aws {
    account_id = "956993596390"
  }
}

# Grant VantaExtensiveOrganizationScanner role to the scanner principal in the identity pool
resource "google_organization_iam_binding" "vanta_org_binding" {
  depends_on = [
    google_iam_workload_identity_pool_provider.vanta_identity_provider,
    google_organization_iam_custom_role.vanta_org_scanner_role
  ]

  org_id = var.org_id
  role   = "organizations/${var.org_id}/roles/VantaExtensiveOrganizationScanner"
  members = [
    local.vanta_scanner_subject_uri
  ]
}

# Wait for the pool to be created
resource "time_sleep" "wait_for_changes_to_propagate" {
  depends_on = [time_sleep.wait_for_vanta_scanner_pool_creation]
  create_duration = "60s"
}
