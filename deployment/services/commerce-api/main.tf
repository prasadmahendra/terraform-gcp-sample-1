terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

locals {

  # hpa_idle_number_of_replicas = var.environment == "prod" ? 29 : 2
  # hpa_min_number_of_replicas  = var.environment == "prod" ? 30 : 3
  # hpa_max_number_of_replicas  = var.environment == "prod" ? 60 : 8
  hpa_idle_number_of_replicas = var.environment == "prod" ? 54 : 2
  hpa_min_number_of_replicas  = var.environment == "prod" ? 55 : 3
  hpa_max_number_of_replicas  = var.environment == "prod" ? 110 : 8
  container_port              = 8080
  service_port                = 9350
  commerce_synthetics_org_names = [
    "spanx",
    "supergoop",
    "coterie",
    "carbahn",
    "mantra-brand",
    "unique-vintage",
    "for-love-and-lemons",
    "wolfmattress",
    "tushbaby"
  ]
  commerce_synthetics_limit_products = var.environment == "prod" ? 1 : 1 # DEV is slow to complete 2 product turns in under 1 minute
  # commerce_api_cpu_request           = var.environment == "prod" ? 2 : 0.5
  commerce_api_cpu_request           = var.environment == "prod" ? 2 : 2
  commerce_api_cpu_limit             = var.environment == "prod" ? 4 : 4

  
  search_synthetics_org_names = [
    "carbahn",
    "mantra-brand",
    "bandolier"
  ]
  search_synthetics_limit_products = var.environment == "prod" ? 3 : 3
}

data "google_secret_manager_secret_version" "launchdarkly-api-key" {
  secret  = "launchdarkly_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
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

data "google_secret_manager_secret_version" "elastic-search-api-key" {
  secret  = "elastic-search-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elasticsearch-cloud-id" {
  secret  = "elasticsearch_cloud_id"
  project = var.project_id
}

data "google_secret_manager_secret_version" "huggingface-access-token" {
  secret  = "huggingface-access-token"
  project = var.project_id
}

data "google_secret_manager_secret_version" "huggingface-endpoint-access-token" {
  secret  = "huggingface-endpoint-access-token"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-auth-token-signing-secret" {
  secret  = "spiffy-auth-token-signing-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "ratelimits-bypass-key" {
  secret  = "ratelimits-bypass-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
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

data "google_secret_manager_secret_version" "slack_app_ai_studio_feedback_webhook_url" {
  secret  = "slack_app_ai_studio_feedback_webhook_url"
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

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

# TODO: Scope down the API key used here! too broad!
data "google_secret_manager_secret_version" "spiffy-api-key" {
  secret  = "spiffy-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-api-key-prod" {
  secret  = "spiffy-api-key-prod"
  project = var.project_id
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bt_access" {
  role_id     = "spiffy.commerceApiSvcBigTableRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - BT access"
  description = "Terraform Managed - Role for ${var.service_name} service"
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
      "bigtable.tables.mutateRows"
    ]
  )
}


resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcs_access" {
  role_id     = "spiffy.commerceApiSvcGcsAccessRole"
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
resource.name.startsWith("projects/_/buckets/spiffy-cs-attachments-${var.environment}")
EXPR
  }
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role_sql" {
  role_id     = "spiffy.commerceApiSvcSqlAccessRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - cloudsql access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ]
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_warm_session_bq_access" {
  role_id     = "spiffy.commerceApiSvcWarmSessionBqRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - warm session BigQuery access"
  description = "Terraform Managed - read warm-session analytics data for ${var.service_name}"
  permissions = [
    "bigquery.datasets.get",
    "bigquery.tables.get",
    "bigquery.tables.getData",
    "bigquery.tables.list",
  ]
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_pubsub_access" {
  role_id     = "spiffy.commerceApiSvcPubSubRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - pubsub topics access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "pubsub.topics.attachSubscription",
      "pubsub.topics.publish",
    ],
  )
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_pubsub_unscoped_access" {
  role_id     = "spiffy.commerceApiSvcPubSubUnscopedRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - pubsub subs access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "pubsub.subscriptions.create",
      "pubsub.subscriptions.consume",
      "pubsub.snapshots.seek"
    ],
  )
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

resource "google_project_iam_member" "iam_member_for_custom_role_warm_session_bq_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_warm_session_bq_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow warm-session big-query access"
    description = "Terraform Managed - read AmplitudeEvents and analytics warm-session data"
    expression  = <<EXPR
resource.name == "projects/${var.project_id}/datasets/AmplitudeEvents" ||
resource.name.startsWith("projects/${var.project_id}/datasets/AmplitudeEvents/") ||
resource.name == "projects/${var.project_id}/datasets/analytics" ||
resource.name.startsWith("projects/${var.project_id}/datasets/analytics/")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_warm_session_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "iam_member_for_custom_role_bt_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_bt_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_bigtable_table_iam_member" "iam_custom_role_for_service_bt_access" {
  count    = length(var.cdp_streams_bigtable_events_table_ids)
  table    = var.cdp_streams_bigtable_events_table_ids[count.index]
  instance = var.cdp_streams_bigtable_instance_id
  role     = google_project_iam_custom_role.iam_custom_role_for_service_bt_access.id
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "iam_member_for_custom_role_pubsub_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_pubsub_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  #   condition {
  #     title       = "Allow pubsub access"
  #     description = "Terraform Managed - Allow pubsub access"
  #     expression  = <<EXPR
  # resource.name.startsWith("${var.chat_sessions_topic_id}")
  # EXPR
  #   }
}

resource "google_project_iam_member" "iam_custom_role_for_service_pubsub_unscoped_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_pubsub_unscoped_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
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
    expression  = "resource.name.startsWith(\"${var.datastore_id}\")"
  }
}

# allow service to read secrets starting with partner_secrets_for_org_
resource "google_project_iam_member" "iam_member_for_custom_role_secrets_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  condition {
    title       = "Allow  secrets read access"
    description = "Terraform Managed - Allow secrets read access"
    expression  = <<EXPR
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
  profiling_enabled = var.environment == "dev" ? true : false
  container_command = ["ddtrace-run"]
  container_command_args = [
    "python3",
    "spiffy/service/commerce_api/__main__.py"
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
  # liveness_probe = null
  # readiness_probe = null
  project_number                             = var.project_number
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  is_public                                  = true
  kubernetes_namespace                       = var.gke_cluster_namespace
  managed_ssl_certificate_name               = var.managed_ssl_certificate_name
  number_of_replicas                         = local.hpa_idle_number_of_replicas
  persistent_volumes                         = []
  limits_cpus                                = local.commerce_api_cpu_limit
  limits_memory                              = "6Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = local.commerce_api_cpu_request
  requests_memory                            = "4Gi"
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
      name      = "VLLM_API_KEY"
      value     = data.google_secret_manager_secret_version.vllm-api-key.secret_data
      sensitive = true
    },
    {
      name      = "HUGGINGFACE_ACCESS_TOKEN"
      value     = data.google_secret_manager_secret_version.huggingface-access-token.secret_data
      sensitive = true
    },
    {
      name      = "HUGGINGFACE_ENDPOINT_ACCESS_TOKEN"
      value     = data.google_secret_manager_secret_version.huggingface-endpoint-access-token.secret_data
      sensitive = true
    },
    {
      name      = "HUGGINGFACE_ENDPOINT_URL"
      value     = var.environment == "dev" ? "https://mgi7c4l2hdqxohs6.us-east4.gcp.endpoints.huggingface.cloud" : "https://rf4i60tpt2y2blef.us-east4.gcp.endpoints.huggingface.cloud"
      sensitive = true
    },
    {
      name  = "TEXT_EMBEDDINGS_ENDPOINT_URL"
      value = var.text_embed_endpoint_url
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
      name  = "CHAT_SESSIONS_REMOTE_STORAGE_ENABLED"
      value = "true"
    },
    {
      name  = "ENABLE_CHAT_SESSIONS_CDP_DATA"
      value = "false"
    },
    {
      name  = "ENABLE_CHAT_SESSIONS_CUSTOMER_INSIGHTS"
      value = var.environment == "dev" ? "false" : "false"
    },
    {
      name  = "CHAT_SESSIONS_PUBSUB_TOPIC_ID"
      value = var.chat_sessions_topic_id
    },
    {
      name  = "CDP_STREAMS_BIGTABLE_INSTANCE_ID"
      value = var.cdp_streams_bigtable_instance_id
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    },
    {
      name      = "SPIFFY_USER_AUTH_TOKEN_SIGNING_SECRET"
      value     = data.google_secret_manager_secret_version.spiffy-auth-token-signing-secret.secret_data
      sensitive = true
    },
    {
      name      = "RATELIMIT_BYPASS_KEY"
      value     = data.google_secret_manager_secret_version.ratelimits-bypass-key.secret_data
      sensitive = true
    },
    {
      name  = "TRANSFORMERS_VERBOSITY"
      value = "warning"
    },
    {
      name      = "STATSIG_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_api_key.secret_data
      sensitive = true
    },
    {
      name      = "LAUNCHDARKLY_SDK_KEY"
      value     = data.google_secret_manager_secret_version.launchdarkly-api-key.secret_data
      sensitive = true
    },
    {
      name  = "USE_LAUNCHDARKLY"
      value = var.environment == "false"
    },
    {
      name  = "SLACK_APP_AI_STUDIO_FEEDBACK_WEBHOOK_URL"
      value = data.google_secret_manager_secret_version.slack_app_ai_studio_feedback_webhook_url.secret_data
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
      name  = "DD_TRACE_OPENAI_ENABLED"
      value = "false"
    },
    {
      name  = "VLLM_LLAMA-3_70B_REGION_USC1_SUPPORTS_QUANTIZED_MODELS"
      value = var.environment == "prod" ? "true" : "false"
    },
    {
      name  = "VLLM_LLAMA-3_70B_REGION_USC1_SUPPORTS_NON_QUANTIZED_MODELS"
      value = var.environment == "prod" ? "false" : "true"
    },
    {
      name  = "VLLM_LLAMA-3_70B_REGION_USW1_SUPPORTS_QUANTIZED_MODELS"
      value = var.environment == "prod" ? "true" : "false"
    },
    {
      name  = "VLLM_LLAMA-3_70B_REGION_USW1_SUPPORTS_NON_QUANTIZED_MODELS"
      value = var.environment == "prod" ? "false" : "true"
    },
    {
      name  = "INFERENCE_REGIONS_8B_STRING_LIST"
      value = var.environment == "prod" ? "usw1,usc1" : "usc1"
    },
    {
      name = "INFERENCE_REGIONS_70B_STRING_LIST",
      value=  var.environment == "prod" ? "usw1,usc1" : "usc1"
    },
    {
      name = "DD_DYNAMIC_INSTRUMENTATION_ENABLED"
      value = var.environment == "dev" ? "false" : "false" # Costs $$$s. Careful with enabling, esp in prod.
    },
    {
      name = "DD_SYMBOL_DATABASE_UPLOAD_ENABLED"
      value = var.environment == "dev" ? "false" : "false" # Costs $$$s. Careful with enabling, esp in prod.
    },
    {
      name = "MOCK_GPU_CALLS"
      value = var.environment == "dev" ? "false" : "false"
    },
    {
      name = "DISABLE_RATE_LIMITING"
      value = var.environment == "dev" ? "false" : "false"
    },
    {
      name  = "AUTH0_DOMAIN_SPA"
      value = data.google_secret_manager_secret_version.auth0_domain_spa.secret_data
    },
    {
      name  = "AUTH0_CLIENT_ID_SPA"
      value = data.google_secret_manager_secret_version.auth0_client_id_spa.secret_data
    },
    {
      name      = "AUTH0_CLIENT_SECRET_SPA"
      value     = data.google_secret_manager_secret_version.auth0_client_secret_spa.secret_data
      sensitive = true
    },
    {
      name  = "AUTH0_AUDIENCE_SPA_APP"
      value = data.google_secret_manager_secret_version.auth0_audience_spa.secret_data
    },
    {
      name  = "AUTH0_DOMAIN_M2M"
      value = data.google_secret_manager_secret_version.auth0_domain_m2m.secret_data
    },
    {
      name  = "AUTH0_CLIENT_ID_M2M"
      value = data.google_secret_manager_secret_version.auth0_client_id_m2m.secret_data
    },
    {
      name      = "AUTH0_CLIENT_SECRET_M2M"
      value     = data.google_secret_manager_secret_version.auth0_client_secret_m2m.secret_data
      sensitive = true
    },
    {
      name  = "AUTH0_AUDIENCE_M2M"
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

resource "datadog_synthetics_test" "deep_health_checks" {
  count     = 0 # Disabled - these are created via pymono now length(local.commerce_synthetics_org_names)
  name      = "[${var.environment}] commerce-api extended health checks - org ${local.commerce_synthetics_org_names[count.index]} (Managed By Terraform)"
  type      = "api"
  subtype   = "http"
  status    = "live"
  message   = var.environment == "prod" ? "Notify @slack-engineering-alerts @oncall-platform-engineering @opsgenie-datadog" : "Notify @slack-engineering-alerts-dev"
  locations = var.environment == "prod" ? ["gcp:us-west1"] : ["gcp:${var.region}"]
  tags      = ["env:${var.environment}"]

  request_definition {
    method = "GET"
    url    = "https://${var.domain_name_public}/healthex?deep=true&limit_org_short_names=${local.commerce_synthetics_org_names[count.index]}&limit_products=${local.commerce_synthetics_limit_products}"
  }

  request_headers = {
    Content-Type  = "application/json"
    Authorization = "Bearer ${data.google_secret_manager_secret_version.spiffy-api-key.secret_data}" # TODO: Scope down the API key used here! too broad!
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  options_list {
    monitor_priority = 1
    tick_every       = 900
    retry {
      count    = 3
      interval = 5000
    }
    monitor_options {
      renotify_interval = 120
    }
  }
}

resource "datadog_synthetics_test" "deep_health_checks_search" {
  count     = length(local.search_synthetics_org_names)
  name      = "[${var.environment}] commerce-api search health checks - org ${local.search_synthetics_org_names[count.index]} (Managed By Terraform)"
  type      = "api"
  subtype   = "http"
  status    = "live"
  message   = var.environment == "prod" ? "Notify @slack-engineering-alerts @oncall-platform-engineering @opsgenie-datadog" : "Notify @slack-engineering-alerts-dev"
  locations = var.environment == "prod" ? ["gcp:us-west1"] : ["gcp:${var.region}"]
  tags      = ["env:${var.environment}"]

  request_definition {
    method = "GET"
    url    = "https://${var.domain_name_public}/healthex?deep=true&limit_org_short_names=${local.search_synthetics_org_names[count.index]}&limit_products=${local.search_synthetics_limit_products}&is_search_check=true"
  }

  request_headers = {
    Content-Type  = "application/json"
    Authorization = "Bearer ${data.google_secret_manager_secret_version.spiffy-api-key.secret_data}" # TODO: Scope down the API key used here! too broad!
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  options_list {
    monitor_priority = 1
    tick_every       = 900
    retry {
      count    = 3
      interval = 5000
    }
    monitor_options {
      renotify_interval = 120
    }
  }
}

module "service_keda_horizontal_pod_autoscaler" {
  source = "../../../modules/create_gke_hpa_keda_datadog"
  depends_on = [
    module.service
  ]

  environment                     = var.environment
  max_replica_count               = local.hpa_max_number_of_replicas
  min_replica_count               = local.hpa_min_number_of_replicas
  idle_replica_count              = local.hpa_idle_number_of_replicas
  namespace                       = var.gke_cluster_namespace
  project_id                      = var.project_id
  scale_target_ref                = module.service.kubernetes_deployment_target_ref
  scaled_object_name              = "${var.service_name}-scaledobject"
  cool_down_period_seconds        = 300
  project_number                  = var.project_number
  service_account_name            = module.service.kubernetes_service_account
  datadog_metric_name             = "waitress-queue-depth-commerce-api"
  datadog_metric_namespace        = var.gke_cluster_namespace
  datadog_metric_query            = "ewma_5(sum:python.waitress.queue{env:${var.environment}, service:commerce-api}.weighted())"
  datadog_activation_query_value  = "0"
  datadog_target_value            = "2"
  datadog_age_time_window_seconds = "300"
  datadog_use_cluster_agent_proxy = "false"
  datadog_metric_unavailable_value = "0"
}
