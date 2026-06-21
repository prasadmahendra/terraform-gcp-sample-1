# CEL spec: https://cloud.google.com/iam/docs/conditions-overview
# Full resource names: https://cloud.google.com/iam/docs/full-resource-names
# Resource Types with Conditional Roles: https://cloud.google.com/iam/docs/resource-types-with-conditional-roles

# Conditions Example:
#   condition {
#    title       = "Allow CloudSQL access for Backend Engineers [DEV]"
#    description = "Terraform Managed - Allow CloudSQL access for Backend Engineers [DEV]"
#    expression  = <<EXPR
#resource.name.startsWith("projects/${local.backend_engineers_role_related_properties.dev_project_number}") ||
#resource.name.startsWith("projects/${local.backend_engineers_role_related_properties.dev_project_id}")
#EXPR
#  }

resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_bigtable_access_for_dev" {
  role_id = "spiffy.BackendEngineersRoleBigTableAccessDev"
  org_id  = var.org_id
  title   = "Backend Engineers Role - BigTable Access [DEV]"
  description = "Terraform Managed - Role for Backend Engineers - BigTable Access [DEV]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    "bigtable.tables.readRows",
    "bigtable.tables.get",
    "bigtable.tables.list",
    "bigtable.instances.get",
    "bigtable.instances.list",
    "bigtable.instances.ping",
    "bigtable.clusters.get",
    "bigtable.clusters.list",
  ]
}

resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_gcs_access_for_dev" {
  role_id = "spiffy.BackendEngineersRoleGcsAccessDev"
  org_id  = var.org_id
  title   = "Backend EngineersRole - GCS Access [DEV]"
  description = "Terraform Managed - Role for Backend Engineers- GCS Access [DEV]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.create",
    "storage.objects.delete",
  ]
}

resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_gcs_access_unrestricted_for_dev" {
  role_id = "spiffy.BackendEngineersRoleGcsUnrestrictedAccessDev"
  org_id  = var.org_id
  title   = "Backend EngineersRole - GCS Unrestricted Access [DEV]"
  description = "Terraform Managed - Role for Backend Engineers- GCS Unrestricted Access [DEV]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    "storage.buckets.list",
  ]
}

resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_service_usage_for_dev" {
  role_id = "spiffy.serviceUsageRoleForBackendEngineersDev"
  org_id  = var.org_id
  title   = "Backend EngineersRole - Service Usage Access [DEV]"
  description = "Terraform Managed - Role for Backend Engineers- Service Usage Access [DEV]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    "monitoring.timeSeries.list",
    "serviceusage.quotas.get",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "serviceusage.services.use",
  ]
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_bigtable_access_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_bigtable_access_for_dev.id
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_gcs_access_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_gcs_access_for_dev.id
  member = local.gsuite_backend_engineers_group_id

  condition {
    title       = "Allow GCS access for Backend Engineers [DEV]"
    description = "Terraform Managed - Allow GCS access for Backend Engineers [DEV]"
    # Don't allow spiffy-tfstate-dev bucket access for backend engineers
    # TODO: Limit access to only the required buckets by project id
    # resource.name.matches("^projects/_/buckets/.*-dev")
    # https://cloud.google.com/iam/docs/conditions-overview
    expression  = <<EXPR
!resource.name.startsWith("projects/_/buckets/spiffy-tfstate")
EXPR
  }
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_gcs_unrestricted_access_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_gcs_access_unrestricted_for_dev.id
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_gke_access_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role = "roles/container.admin"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloud_build_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/cloudbuild.builds.editor"
  member = local.gsuite_backend_engineers_group_id
}

# cloud logs
resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_cloud_logs_for_dev" {
  role_id = "spiffy.BackendEngineersRoleCloudLogsAccessDev"
  org_id  = var.org_id
  title   = "Backend EngineersRole - CloudBuild Access [DEV]"
  description = "Terraform Managed - Role for Backend Engineers- CloudBuild Access [DEV]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    // XX
    "logging.buckets.get",
    "logging.buckets.list",
    "logging.exclusions.get",
    "logging.exclusions.list",
    "logging.links.get",
    "logging.links.list",
    "logging.locations.get",
    "logging.locations.list",
    "logging.logEntries.list",
    "logging.logMetrics.get",
    "logging.logMetrics.list",
    "logging.logServiceIndexes.list",
    "logging.logServices.list",
    "logging.logs.list",
    "logging.operations.get",
    "logging.operations.list",
    "logging.queries.getShared",
    "logging.queries.listShared",
    "logging.queries.usePrivate",
    "logging.sinks.get",
    "logging.sinks.list",
    "logging.usage.get",
    "logging.views.get",
    "logging.views.list",
    "observability.scopes.get",
    "resourcemanager.projects.get",
  ]
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloud_logs_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_cloud_logs_for_dev.id
  member = local.gsuite_backend_engineers_group_id
}

# pubsub access
resource "google_organization_iam_custom_role" "org_role_for_backend_engineers_pubsub_for_dev" {
  role_id = "spiffy.BackendEngineersRolePubSubAccessDev"
  org_id  = var.org_id
  title   = "Backend EngineersRole - PubSub Access [DEV]"
  description = "Terraform Managed - Role for Backend Engineers- PubSub Access [DEV]"
  # https://cloud.google.com/bigtable/docs/access-control
  permissions = [
    "pubsub.schemas.attach",
    "pubsub.schemas.commit",
    "pubsub.schemas.create",
    "pubsub.schemas.delete",
    "pubsub.schemas.get",
    "pubsub.schemas.list",
    "pubsub.schemas.listRevisions",
    "pubsub.schemas.rollback",
    "pubsub.schemas.validate",
    "pubsub.snapshots.create",
    "pubsub.snapshots.delete",
    "pubsub.snapshots.get",
    "pubsub.snapshots.list",
    "pubsub.snapshots.seek",
    "pubsub.snapshots.update",
    "pubsub.subscriptions.consume",
    "pubsub.subscriptions.create",
    "pubsub.subscriptions.delete",
    "pubsub.subscriptions.get",
    "pubsub.subscriptions.list",
    "pubsub.subscriptions.update",
    "pubsub.topics.attachSubscription",
    "pubsub.topics.create",
    "pubsub.topics.delete",
    "pubsub.topics.detachSubscription",
    "pubsub.topics.get",
    "pubsub.topics.list",
    "pubsub.topics.publish",
    "pubsub.topics.update",
    "pubsub.topics.updateTag",
    "resourcemanager.projects.get",
    "serviceusage.quotas.get",
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_pubsub_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_pubsub_for_dev.id
  member = local.gsuite_backend_engineers_group_id
}

# Worker pool user role
# Required for creating and managing worker pools
# Also see: https://www.googlecloudcommunity.com/gc/Developer-Tools/Unable-to-retry-cloud-build-with-private-pool/m-p/609067
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_worker_pool_editor_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/cloudbuild.workerPoolUser"
  member = local.gsuite_backend_engineers_group_id
}

# Secrets access
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_secrets_manager_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/secretmanager.admin"
  member = local.gsuite_backend_engineers_group_id
}

# compute engine access
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_compute_engine_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/compute.admin"
  member = local.gsuite_backend_engineers_group_id
}

# datastore access
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_datastore_access_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/datastore.owner"
  member = local.gsuite_backend_engineers_group_id
}

# cloudsql access - roles/cloudsql.admin
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloudsql_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/cloudsql.admin"
  member = local.gsuite_backend_engineers_group_id
}

# project resources role - roles/browser
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_browser_role_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/browser"
  member = local.gsuite_backend_engineers_group_id
}

# monitoring access - roles/monitoring.admin
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_monitoring_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/monitoring.admin"
  member = local.gsuite_backend_engineers_group_id
}

# artifacts registry access - roles/artifactregistry.repoAdmin
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_artifact_registry_writer_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/artifactregistry.repoAdmin"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_artifact_registry_writer_for_dev_to_prod" {
  folder = google_folder.spiffy-org-eng-gcp-env-prod-folder.id # artifact registry is in prod
  role   = "roles/artifactregistry.reader" # Must be R/O access. Only CI/CD is allowed to push
  member = local.gsuite_backend_engineers_group_id
}

# roles/iam.serviceAccountUser is required to grant groups access to compute engine
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_service_accounts_role_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/iam.serviceAccountUser"
  member = local.gsuite_backend_engineers_group_id
}

# roles/cloudscheduler.admin
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloudscheduler_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/cloudscheduler.admin"
  member = local.gsuite_backend_engineers_group_id
}

# roles/redis.editor
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_redis_editor_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/redis.editor"
  member = local.gsuite_backend_engineers_group_id
}

# roles/run.developer
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_cloud_run_developer_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/run.developer"
  member = local.gsuite_backend_engineers_group_id
}

# service usage access
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_service_usage_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = google_organization_iam_custom_role.org_role_for_backend_engineers_service_usage_for_dev.id
  member = local.gsuite_backend_engineers_group_id
}

# SSH via IAP access
# grant these - https://cloud.google.com/iap/docs/using-tcp-forwarding#firewall
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_tunnel_resource_access_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/iap.tunnelResourceAccessor"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_compute_instance_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/compute.instanceAdmin.v1"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_storage_transfer_user_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/storagetransfer.user"
  member = local.gsuite_backend_engineers_group_id
}

resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_service_usage_consumer_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/serviceusage.serviceUsageConsumer"
  member = local.gsuite_backend_engineers_group_id
}

# roles/bigquery.admin
resource "google_folder_iam_member" "organization_iam_binding_for_backend_engineers_bigquery_admin_for_dev" {
  folder = google_folder.spiffy-org-eng-gcp-env-dev-folder.id
  role   = "roles/bigquery.admin"
  member = local.gsuite_backend_engineers_group_id
}