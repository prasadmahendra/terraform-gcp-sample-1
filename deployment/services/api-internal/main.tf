terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  number_of_replicas = var.environment == "prod" ? 2 : 2
  container_port     = 8080
  service_port       = 9340
  dev_api_internal_service_account_email = var.dev_api_internal_service_account_email
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elastic-search-api-key" {
  secret  = "elastic-search-api-key"
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

data "google_secret_manager_secret_version" "anthropic-api-key" {
  secret  = "anthropic-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "segment-api-key" {
  secret  = "segment-key-for-python-api"
  project = var.project_id
}

data "google_secret_manager_secret_version" "vllm-api-key" {
  secret  = "vllm-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-auth-token-signing-secret" {
  secret  = "spiffy-auth-token-signing-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "klaviyo-client-id" {
  secret  = "klaviyo-client-id"
  project = var.project_id
}

data "google_secret_manager_secret_version" "klaviyo-client-secret" {
  secret  = "klaviyo-client-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elasticsearch-cloud-id" {
  secret  = "elasticsearch_cloud_id"
  project = var.project_id
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_console_api_key" {
  secret  = "statsig_console_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-key-readonly" {
  secret  = "amplitude-api-key-readonly"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-secret-readonly" {
  secret  = "amplitude-api-secret-readonly"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-api-dev-secret" {
  secret  = "spiffy-api-dev-env-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-api-key-prod" {
  secret  = "spiffy-api-key-prod"
  project = var.project_id
}

data "google_secret_manager_secret_version" "temporal-api-key" {
  secret  = "temporal-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "slack_app_config_changes_webhook_url" {
  secret  = "slack_app_config_changes_webhook_url"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_client_id_spa" {
  secret  = "webapp-admin-auth0-client-id"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_client_secret_spa" {
  secret  = "webapp-admin-auth0-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_domain_spa" {
  secret  = "webapp-admin-auth0-domain"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_audience_spa" {
  secret  = "webapp-admin-auth0-audience"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_client_id_m2m" {
  secret  = "auth0_client_id_m2m"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_client_secret_m2m" {
  secret  = "auth0_client_secret_m2m"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_domain_m2m" {
  secret  = "auth0_domain_m2m"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_audience_m2m" {
  secret  = "auth0_audience_m2m"
  project = var.project_id
}

data "google_secret_manager_secret_version" "auth0_idp_connection_id" {
  secret  = "auth0_idp_connection_id"
  project = var.project_id
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bq_access" {
  role_id     = "spiffy.apiInternalSvcBigQueryRole"
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

resource "google_project_iam_custom_role" "secretmanager_secrets_admin" {
  role_id = "webAppAdminSvcRole_SecretsAccess"
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

resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcs_access" {
  role_id = "spiffy.apiSvcGcsAccessRole"
  project = var.project_id
  title   = "Role for ${var.service_name} - GCS access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
    "storage.objects.delete",
    # "iam.serviceAccounts.signBlob"
  ]
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
resource.name.startsWith("projects/_/buckets/spiffy-llm-inference-service-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-data-ingestion-pipeline-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-chat-frontend-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-cs-attachments-${var.environment}")
EXPR
  }
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_resource_unrestricted" {
  role_id     = "spiffy.apiInternalSvcBigQueryUnscopedRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "bigquery.jobs.create",
    ]
  )
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role_sql" {
  role_id     = "spiffy.apiInternalSvcSqlAccessRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ]
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
resource.name == "projects/${var.project_id}/datasets/AmplitudeEvents" ||
resource.name.startsWith("projects/${var.project_id}/datasets/AmplitudeEvents/") ||
resource.name == "projects/${var.project_id}/datasets/analytics" ||
resource.name.startsWith("projects/${var.project_id}/datasets/analytics/")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_bq_prod_jobs" {
  count   = var.environment == "prod" ? 1 : 0
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_resource_unrestricted.id
  member  = "serviceAccount:${local.dev_api_internal_service_account_email}"
}

resource "google_project_iam_member" "iam_member_for_custom_role_bq_prod_access" {
  count   = var.environment == "prod" ? 1 : 0
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_bq_access.id
  # Grant dev service account access to prod bigquery dataset
  member  = "serviceAccount:${local.dev_api_internal_service_account_email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  condition {
    title       = "Allow big-query access"
    description = "Terraform Managed - Allow big-query access"
    expression  = <<EXPR
resource.name == "projects/${var.project_id}/datasets/AmplitudeEvents" ||
resource.name.startsWith("projects/${var.project_id}/datasets/AmplitudeEvents/") ||
resource.name == "projects/${var.project_id}/datasets/analytics" ||
resource.name.startsWith("projects/${var.project_id}/datasets/analytics/")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_bq_jobs" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_resource_unrestricted.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "iam_member_for_custom_role_cloudsql_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.google_project_iam_custom_role_sql.id
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

# give datastore access to service if required
resource "google_project_iam_member" "service_account_for_cloud_run_datastore_access" {

  count   = var.datastore_id != null ? 1 : 0
  member  = "serviceAccount:${google_service_account.service_account.email}"
  role    = "roles/datastore.user"
  project = var.project_id

  condition {
    title       = "Allow datastore access"
    description = "Terraform Managed - Allow datastore access"
    expression  = "resource.name.startsWith(\"${var.datastore_id}\") || resource.name.startsWith(\"projects/${var.project_id}/databases/spiffy-monitoring-store\")"
  }
}

# create a role for secretmanager.secrets.create
resource "google_project_iam_custom_role" "iam_custom_role_for_secretmanager_secrets_create_project_level" {
  role_id     = "spiffy.apiInternalSvcSecretManagerProjectRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "secretmanager.secrets.create",
  ]
}

resource "google_project_iam_member" "iam_member_for_custom_role_secretmanager_secrets_create_project_level" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_secretmanager_secrets_create_project_level.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
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

resource "google_project_iam_member" "service_account_for_secrets_manager_adder_access" {
  member  = "serviceAccount:${google_service_account.service_account.email}"
  role    = "roles/secretmanager.secretVersionAdder"
  project = var.project_id

  # limit to projects/spiffy-ai-dev/secrets/spiffy-commerce-chat-api-keys .. only
  condition {
    title       = "Allow secrets manager adder access"
    description = "Terraform Managed - Allow secrets manager adder access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/secrets/spiffy-commerce-chat-api-keys") ||
resource.name.startsWith("projects/${var.project_number}/secrets/spiffy-commerce-chat-api-keys")
EXPR
  }
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
resource.name.startsWith("projects/${var.project_number}/secrets/partner_secrets_for_org_")
EXPR
  }
}

module "service" {
  source            = "../../../modules/create_gke_http_service"
  environment       = var.environment
  service_name      = var.service_name
  project_id        = var.project_id
  subnet            = var.subnet
  region            = var.region
  profiling_enabled = var.environment == "dev" ? false : false
  container_command = ["ddtrace-run"]
  container_command_args = [
    "python3",
    "spiffy/service/api/__main__.py"
  ]
  container_dns_label               = var.service_name
  container_port                    = local.container_port
  docker_image                      = var.docker_image
  docker_image_tag                  = var.docker_image_tag
  enable_service_directory_registry = false
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    id         = google_service_account.service_account.id
    account_id = google_service_account.service_account.account_id
  }
  liveness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.container_port
    }
    initial_delay_seconds = 15
    period_seconds        = 5
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 5
  }
  readiness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.container_port
    }
    initial_delay_seconds = 15
    period_seconds        = 5
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 5
  }
  project_number                             = var.project_number
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  is_public                                  = true
  # runMcpPrompt runs a synchronous LLM<->MCP loop that can exceed GCP's 30s
  # default; raise the LB timeout so it isn't severed with a 503 (the app caps
  # itself at ~100s via McpPlaygroundService._PLAYGROUND_DEADLINE_SECONDS).
  backend_request_timeout_sec                = 120
  kubernetes_namespace                       = var.gke_cluster_namespace
  managed_ssl_certificate_name               = var.managed_ssl_certificate_name
  number_of_replicas                         = local.number_of_replicas
  persistent_volumes = []
  limits_cpus                                = 2
  limits_memory                              = "8Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 1
  requests_memory                            = "8Gi"
  requests_nvidia_gpus                       = null
  service_port                               = local.service_port
  apm_enabled                                = true
  service_fqdn                               = var.domain_name_public
  private_dns_zone_name                      = var.dns_zone_name_private
  public_dns_zone_name                       = var.dns_zone_name_public
  cloudsql_databases = [
    {
      port                     = 5432
      instance_connection_name = var.database_connection_name
    }
  ]
  env = [
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
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
      name      = "ANTHROPIC_API_KEY"
      value     = data.google_secret_manager_secret_version.anthropic-api-key.secret_data
      sensitive = true
    },
    {
      name      = "SEGMENT_WRITE_KEY"
      value     = data.google_secret_manager_secret_version.segment-api-key.secret_data
      sensitive = true
    },
    {
      name      = "VLLM_API_KEY"
      value     = data.google_secret_manager_secret_version.vllm-api-key.secret_data
      sensitive = true
    },
    {
      name      = "SPIFFY_USER_AUTH_TOKEN_SIGNING_SECRET"
      value     = data.google_secret_manager_secret_version.spiffy-auth-token-signing-secret.secret_data
      sensitive = true
    },
    {
      name      = "KLAVIYO_CLIENT_ID"
      value     = data.google_secret_manager_secret_version.klaviyo-client-id.secret_data
      sensitive = true
    },
    {
      name      = "KLAVIYO_CLIENT_SECRET"
      value     = data.google_secret_manager_secret_version.klaviyo-client-secret.secret_data
      sensitive = true
    },
    {
      name  = "LOGLEVEL"
      value = "INFO"
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
      name  = "SPIFFY_ORG_USERS_WHITELIST"
      value = "{\"spiffy_ai\":[], \"coterie\":[\"sameeersingh@gmail.com\"]}"
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
      name  = "CDP_MKT_PLACE_APP_INSTALLS_CREATE_ORG_IF_NOT_FOUND"
      value = var.environment == "prod" ? "false" : "false"
    },
    {
      # Readonly key
      name      = "AMPLITUDE_API_KEY"
      value     = data.google_secret_manager_secret_version.amplitude-api-key-readonly.secret_data
      sensitive = true
    },
    {
      # Readonly secret
      name      = "AMPLITUDE_API_SECRET"
      value     = data.google_secret_manager_secret_version.amplitude-api-secret-readonly.secret_data
      sensitive = true
    },
    {
      name      = "SPIFFY_API_KEY_DEV"
      value     = data.google_secret_manager_secret_version.spiffy-api-dev-secret.secret_data
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
      name      = "SLACK_APP_CONFIG_CHANGES_WEBHOOK_URL"
      value     = data.google_secret_manager_secret_version.slack_app_config_changes_webhook_url.secret_data
      sensitive = true
    },
    {
      name  = "ANALYTICS_BIGQUERY_PROJECT_ID"
      value = "spiffy-prod"
    },
    {
      name = "AUTH0_DOMAIN_SPA"
      value = data.google_secret_manager_secret_version.auth0_domain_spa.secret_data
    },
    {
      name = "AUTH0_CLIENT_ID_SPA"
      value = data.google_secret_manager_secret_version.auth0_client_id_spa.secret_data
    },
    {
      name = "AUTH0_AUDIENCE_SPA_APP"
      value = data.google_secret_manager_secret_version.auth0_audience_spa.secret_data
    },
    {
      name = "AUTH0_CLIENT_SECRET_SPA"
      value = data.google_secret_manager_secret_version.auth0_client_secret_spa.secret_data
      sensitive = true
    },
    {
      name = "AUTH0_DOMAIN_M2M"
      value = data.google_secret_manager_secret_version.auth0_domain_m2m.secret_data
    },
    {
      name = "AUTH0_CLIENT_ID_M2M"
      value = data.google_secret_manager_secret_version.auth0_client_id_m2m.secret_data
    },
    {
      name = "AUTH0_CLIENT_SECRET_M2M"
      value = data.google_secret_manager_secret_version.auth0_client_secret_m2m.secret_data
      sensitive = true
    },
    {
      name = "AUTH0_AUDIENCE_M2M"
      value = data.google_secret_manager_secret_version.auth0_audience_m2m.secret_data
    },
    {
      name      = "AUTH0_IDP_CONNECTION_ID"
      value     = data.google_secret_manager_secret_version.auth0_idp_connection_id.secret_data
      sensitive = true
    },
    {
      name      = "SPIFFY_API_KEY_PROD"
      value     = data.google_secret_manager_secret_version.spiffy-api-key-prod.secret_data
      sensitive = true
    }
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
  priority = 2
}
