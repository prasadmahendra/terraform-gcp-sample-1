terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

locals {
  number_of_replicas              = var.environment == "prod" ? 2 : 1
  container_port                  = 8080
  service_port                    = 9130
  org_events_topic_id             = "projects/${var.project_id}/topics/cdc-main-db.public.organizations"
  org_config_events_topic_id      = "projects/${var.project_id}/topics/cdc-main-db.public.organizations_config"
  search_indexing_pubsub_topic_id = "projects/${var.project_id}/topics/retrieval-search-indexing"
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-key" {
  secret  = "amplitude-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-secret" {
  secret  = "amplitude-api-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_console_api_key" {
  secret  = "statsig_console_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "openai-api-key" {
  secret  = "openai-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "gemini-api-key" {
  secret  = "gemini-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "vllm-api-key" {
  secret  = "vllm-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "temporal-api-key" {
  secret  = "temporal-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elastic-search-api-key" {
  secret  = "elastic-search-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elasticsearch-cloud-id" {
  secret  = "elasticsearch_cloud_id"
  project = var.project_id
}

data "google_secret_manager_secret_version" "slack_app_eng_alerts_webhook_url" {
  secret  = "slack_app_eng_alerts_webhook_url"
  project = var.project_id
}

data "google_secret_manager_secret_version" "slack_app_eng_alerts_analytics_webhook_url" {
  secret  = "slack_app_eng_alerts_analytics_webhook_url"
  project = var.project_id
}

data "google_secret_manager_secret_version" "zenrows-api-key" {
  secret  = "zenrows-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-api-key" {
  secret  = "spiffy-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "ga4-oauth2-credentials" {
  secret  = "ga4-oauth2-credentials"
  project = var.project_id
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_service_account" "service_account" {
  account_id   = "${substr(var.service_name, 0, 16)}-${lower(random_string.suffix.result)}-sa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_resource_unrestricted" {
  role_id     = "spiffy.orgsSvcBigQueryUnscopedRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "bigquery.jobs.create",
    ]
  )
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bq_access" {
  role_id     = "spiffy.orgsSvcBigQueryRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "bigquery.datasets.get",
      "bigquery.tables.get",
      "bigquery.tables.getData",
      "bigquery.tables.getIamPolicy",
      "bigquery.tables.updateData",
      "bigquery.tables.list",
    ]
  )
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_cloudsql_access" {
  role_id     = "spiffy.organizationsSvcCloudSqlRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "cloudsql.instances.connect",
      "cloudsql.instances.get",
    ],
  )
}

resource "google_project_iam_member" "iam_member_for_custom_role_bq_jobs" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_resource_unrestricted.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "project_iam_member_datastore_access" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "iam_member_for_custom_role_bq_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_bq_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  condition {
    title       = "Allow big-query access"
    description = "Terraform Managed - Allow big-query access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/datasets/AmplitudeEvents") || resource.name == "projects/${var.project_id}/datasets/analytics" || resource.name.startsWith("projects/${var.project_id}/datasets/analytics/")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_cloudsql_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_cloudsql_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  condition {
    title       = "Allow cloudsql access"
    description = "Terraform Managed - Allow cloudsql access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/instances/${var.cloudsql_instance_name}")
EXPR
  }
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcs_access" {
  role_id     = "spiffy.organizationsSvcGcsAccessRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - GCS access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
    "storage.objects.delete",
    "iam.serviceAccounts.signBlob"
  ]
}

# storagetransfer.jobs.run
# https://cloud.google.com/storage-transfer/docs/reference/rest/v1/transferJobs/run
resource "google_project_iam_custom_role" "iam_custom_role_for_service_storagetransfer_access" {
  role_id     = "spiffy.organizationsSvcStorageTransferRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "storagetransfer.jobs.get",
      "storagetransfer.jobs.update",
      "storagetransfer.jobs.run",
      "storagetransfer.jobs.list",
      "storagetransfer.operations.cancel",
      "storagetransfer.operations.get",
      "storagetransfer.operations.list",
      "storagetransfer.operations.pause",
      "storagetransfer.operations.resume",
    ],
  )
}

# Cloud build trigger role
# cloudbuild.builds.create
resource "google_project_iam_custom_role" "iam_custom_role_for_service_cloudbuild_access" {
  role_id     = "spiffy.organizationsSvcCloudBuildRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "cloudbuild.builds.create",
      "cloudbuild.builds.get",
      "cloudbuild.builds.list",
      "cloudbuild.builds.update",
    ],
  )
}

resource "google_project_iam_custom_role" "secretmanager_secrets_admin" {
  role_id = "organizationsSvcRole_SecretsAccess_${random_string.suffix.result}"
  title   = "Secret Manager Secrets Admin"
  permissions = [
    "secretmanager.secrets.create",
    "secretmanager.secrets.delete",
    "secretmanager.secrets.get",
    "secretmanager.secrets.getIamPolicy",
    "secretmanager.secrets.list",
    "secretmanager.secrets.setIamPolicy",
    "secretmanager.secrets.update",
    "secretmanager.versions.access",
    "secretmanager.versions.add",
    "secretmanager.versions.destroy",
    "secretmanager.versions.disable",
    "secretmanager.versions.enable",
    "secretmanager.versions.get",
    "secretmanager.versions.list",
  ]
}

resource "google_project_iam_member" "project_iam_member_secretmanager_secrets_admin" {
  project = var.project_id
  role    = google_project_iam_custom_role.secretmanager_secrets_admin.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # restrict to resources matching projects/spiffy-ai-dev/secrets/partner_secrets_for_org_* only
  condition {
    title       = "Allow secretmanager access"
    description = "Terraform Managed - Allow secretmanager access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/secrets/partner_secrets_for_org_") ||
resource.name.startsWith("projects/${var.project_number}/secrets/partner_secrets_for_org_") ||
resource.name.startsWith("projects/${var.project_id}/secrets/spiffy-commerce-chat-api-keys") ||
resource.name.startsWith("projects/${var.project_number}/secrets/spiffy-commerce-chat-api-keys")
EXPR
  }
}

# give access to secrets manager
# roles/secretmanager.secretVersionAdder and roles/secretmanager.secretAccessor
resource "google_project_iam_member" "service_account_for_secrets_manager_access" {
  member  = "serviceAccount:${google_service_account.service_account.email}"
  role    = "roles/secretmanager.secretAccessor"
  project = var.project_id

  # limit to projects/spiffy-ai-dev/secrets/spiffy-commerce-chat-api-keys .. only
  condition {
    title       = "Allow secrets manager access"
    description = "Terraform Managed - Allow secrets manager access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/secrets/spiffy-commerce-chat-api-keys") ||
resource.name.startsWith("projects/${var.project_number}/secrets/spiffy-commerce-chat-api-keys")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_gcs_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_gcs_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  condition {
    title       = "Allow gcs access"
    description = "Terraform Managed - Allow gcs access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-train-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-models-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-llm-inference-service-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-data-ingestion-pipeline-${var.environment}")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_cloudbuild_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_cloudbuild_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # TODO: Add condition to limit access to specific triggers?
}

resource "google_project_iam_member" "iam_member_for_custom_role_storagetransfer_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_storagetransfer_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # TODO: Add condition to limit access to specific transfer operations?
}

# roles/container.developer
# Lowest-level resources where you can grant this role: Project
resource "google_project_iam_member" "gke_developer_role" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

module "orgs-service-org-events-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "orgs-svc-org-events-processor"
  topic_id                    = local.org_events_topic_id
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
  pull_config = {
    message_retention_duration   = "604800s" # 7 days
    retain_acked_messages        = false
    ack_deadline_seconds         = 20
    expiration_policy_ttl        = "2678400s"
    retry_policy_minimum_backoff = "10s"
    enable_message_ordering      = true
  }
}

module "orgs-service-org-config-events-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "orgs-svc-org-config-events-processor"
  topic_id                    = local.org_config_events_topic_id
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
  pull_config = {
    message_retention_duration   = "604800s" # 7 days
    retain_acked_messages        = false
    ack_deadline_seconds         = 20
    expiration_policy_ttl        = "2678400s"
    retry_policy_minimum_backoff = "10s"
    enable_message_ordering      = true
  }
}

module "orgs-service-topic-permissions" {
  source                       = "../../../modules/create_pubsub_sa_role"
  region                       = var.region
  project_id                   = var.project_id
  service_account_email        = google_service_account.service_account.email
  service_account_service_name = var.service_name
  topic_name                   = local.org_events_topic_id
  deadletter_topic_name        = local.org_events_topic_id
}

module "service" {
  source             = "../../../modules/create_gke_grpc_service"
  number_of_replicas = local.number_of_replicas
  profiling_enabled  = var.environment == "dev" ? false : false
  container_command  = ["python3"]
  container_command_args = [
    "spiffy/service/iam/iam/__orgs_service_main__.py"
  ]
  container_dns_label                        = var.service_name
  container_port                             = local.container_port
  docker_image                               = var.docker_image
  docker_image_tag                           = var.docker_image_tag
  enable_service_directory_registry          = false
  service_directory_namespace_id             = var.service_directory_namespace_id
  environment                                = var.environment
  is_public                                  = false
  kubernetes_namespace                       = var.gke_cluster_namespace
  persistent_volumes                         = []
  project_id                                 = var.project_id
  project_number                             = var.project_number
  limits_cpus                                = 1
  limits_memory                              = "2Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 1
  requests_memory                            = "2Gi"
  requests_nvidia_gpus                       = null
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  service_name                               = var.service_name
  service_port                               = local.service_port
  apm_enabled                                = false
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    id         = google_service_account.service_account.id
    account_id = google_service_account.service_account.account_id
  }
  cloudsql_databases = [
    {
      port                     = 5432
      instance_connection_name = var.database_connection_name
    }
  ]
  liveness_probe = {
    grpc = {
      service_name = "spiffy.service.organizations.OrganizationsService"
      port         = local.container_port
    }
    initial_delay_seconds = 30
    period_seconds        = 5
    timeout_seconds       = 3
    success_threshold     = 1
    failure_threshold     = 5
  }
  readiness_probe = {
    grpc = {
      service_name = "spiffy.service.organizations.OrganizationsService"
      port         = local.container_port
    }
    initial_delay_seconds = 30
    period_seconds        = 5
    timeout_seconds       = 3
    success_threshold     = 1
    failure_threshold     = 5
  }
  env = [
    {
      name  = "LOGLEVEL"
      value = "INFO"
    },
    {
      name  = "POSTGRES_USER"
      value = "maindbuser"
    },
    {
      name  = "POSTGRES_HOSTNAME"
      value = "127.0.0.1" # connect to SQL proxy via private IP
    },
    {
      name      = "POSTGRES_PASSWORD"
      value     = data.google_secret_manager_secret_version.cloudsql-maindb-maindb-password.secret_data
      sensitive = true
    },
    {
      name  = "REDIS_HOST"
      value = var.redis_host
    },
    {
      name  = "REDIS_PORT"
      value = var.redis_port
    },
    {
      name  = "GOOGLE_PROJECT_NUMBER"
      value = var.project_number
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "GOOGLE_CLOUD_DEFAULT_REGION"
      value = var.region_default
    },
    {
      name  = "AMPLITUDE_API_KEY"
      value = data.google_secret_manager_secret_version.amplitude-api-key.secret_data
    },
    {
      name  = "AMPLITUDE_API_SECRET"
      value = data.google_secret_manager_secret_version.amplitude-api-secret.secret_data
    },
    {
      name      = "STATSIG_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_api_key.secret_data
      sensitive = true
    },
    {
      name      = "STATSIG_CONSOLE_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_console_api_key.secret_data
      sensitive = true
    },
    {
      name      = "GA4_OAUTH_CREDENTIALS"
      value     = data.google_secret_manager_secret_version.ga4-oauth2-credentials.secret_data
      sensitive = true
    },
    {
      name  = "TEMPORAL_HOST"
      value = var.temporal_host
    },
    {
      name  = "TEMPORAL_API_KEY"
      value = data.google_secret_manager_secret_version.temporal-api-key.secret_data
    },
    {
      name  = "GOOGLE_DWS_CLUSTER_ID"
      value = var.gke_dws_cluster_name
    },
    {
      name  = "GOOGLE_DWS_CLUSTER_ZONE_ID"
      value = var.gke_dws_cluster_region
    },
    {
      name      = "OPENAI_API_KEY"
      value     = data.google_secret_manager_secret_version.openai-api-key.secret_data
      sensitive = true
    },
    {
      name      = "GEMINI_API_KEY"
      value     = data.google_secret_manager_secret_version.gemini-api-key.secret_data
      sensitive = true
    },
    {
      name  = "SLACK_APP_ENG_ALERTS_WEBHOOK_URL"
      value = data.google_secret_manager_secret_version.slack_app_eng_alerts_webhook_url.secret_data
    },
    {
      name  = "SLACK_APP_ANALYTICS_ALERTS_WEBHOOK_URL"
      value = data.google_secret_manager_secret_version.slack_app_eng_alerts_analytics_webhook_url.secret_data
    },
    {
      name  = "ENABLE_CHAT_SESSIONS_CDP_DATA"
      value = "false"
    },
    {
      name  = "SEARCH_INDEXING_TEMP_DIR"
      value = "/tmp/search_indexing"
    },
    {
      name      = "ELASTIC_SEARCH_API_KEY"
      value     = data.google_secret_manager_secret_version.elastic-search-api-key.secret_data
      sensitive = true
    },
    {
      name      = "ELASTIC_SEARCH_CLOUD_ID"
      value     = data.google_secret_manager_secret_version.elasticsearch-cloud-id.secret_data
      sensitive = true
    },
    {
      name      = "ZENROWS_API_KEY"
      value     = data.google_secret_manager_secret_version.zenrows-api-key.secret_data
      sensitive = true
    },
    {
      name = "DD_API_KEY"
      value = var.datadog_api_key
      sensitive = true
    },
    {
      name = "DD_APP_KEY"
      value = var.datadog_app_key
      sensitive = true
    },
    {
      name = "DD_SITE"
      value = var.datadog_site
      sensitive = true
    },
    {
      name  = "ORG_EVENTS_TOPIC_ID"
      value = local.org_events_topic_id
    },
    {
      name  = "ORG_CONFIG_EVENTS_TOPIC_ID"
      value = local.org_config_events_topic_id
    },
    {
      name  = "SEARCH_INDEXING_PUBSUB_TOPIC_ID"
      value = local.search_indexing_pubsub_topic_id
    },
    {
      name  = "ORGS_SVC_ORG_EVENTS_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.orgs-service-org-events-processor.subscription_name
    },
    {
      name  = "ORGS_SVC_ORG_CONFIG_EVENTS_PROCESSOR_SUBSCRIPTION_ID"
      value = module.orgs-service-org-config-events-processor.subscription_id
    },
    {
      name  = "ORGS_SVC_ORG_CONFIG_EVENTS_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.orgs-service-org-config-events-processor.subscription_name
    },
    {
      name = "SPIFFY_API_KEY"
      value = data.google_secret_manager_secret_version.spiffy-api-key.secret_data
      sensitive = true
    },
  ]
}

module "logs-anomalies-monitoring" {
  source       = "../../../modules/create_dd_logs_anomalies_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name = var.service_name
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcp_scheduler_access" {
  role_id     = "spiffy.searchIdxSvcGcpSchedulerRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "GCP Scheduler Role for ${var.service_name} service"
  description = "Terraform Managed - GCP Scheduler Role for ${var.service_name} service"
  permissions = [
    "cloudscheduler.jobs.create",
    "cloudscheduler.jobs.delete",
    "cloudscheduler.jobs.enable",
    "cloudscheduler.jobs.fullView",
    "cloudscheduler.jobs.get",
    "cloudscheduler.jobs.list",
    "cloudscheduler.jobs.pause",
    "cloudscheduler.jobs.run",
    "cloudscheduler.jobs.update",
    "cloudscheduler.locations.get",
    "cloudscheduler.locations.list"
  ]
}

resource "google_project_iam_member" "iam_member_for_custom_role_gcp_scheduler_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_gcp_scheduler_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}
