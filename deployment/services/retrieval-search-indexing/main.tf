terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  hpa_idle_number_of_replicas                   = var.environment == "prod" ? 5 : 5
  hpa_min_number_of_replicas                    = var.environment == "prod" ? 6 : 6
  hpa_max_number_of_replicas                    = var.environment == "prod" ? 12 : 12
  container_port                                = 8080
  service_port                                  = 9100
  org_config_events_topic_id                    = "projects/${var.project_id}/topics/cdc-main-db.public.organizations_config"
  org_events_topic_id                           = "projects/${var.project_id}/topics/cdc-main-db.public.organizations"
  product_catalog_files_inbound_pubsub_topic_id = var.environment == "dev" ? "projects/spiffy-ai-dev/topics/gcs-spiffy-product-catalogs-receipts-${var.environment}" : "projects/spiffy-prod/topics/gcs-spiffy-product-catalogs-receipts-${var.environment}"
  reindex_merchants = [
    # "coterie",
  ]
}
resource "random_string" "suffix" {
  length  = 6
  special = false
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
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

data "google_secret_manager_secret_version" "zenrows-api-key" {
  secret  = "zenrows-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "temporal-api-key" {
  secret  = "temporal-api-key"
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

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "slack_app_eng_alerts_webhook_url" {
  secret  = "slack_app_eng_alerts_webhook_url"
  project = var.project_id
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-sa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_cloudsql_access" {
  role_id     = "spiffy.searchIdxSvcCloudSqlRole_${random_string.suffix.result}"
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

module "retrieval-search-indexing-topic" {
  source                      = "../../../modules/create_pubsub_topic"
  topic_name                  = "retrieval-search-indexing"
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
}

# points to env name SEARCH_INDEXING_SERVICE_TOPIC_PROCESSOR_SUBSCRIPTION_NAME
module "search-indexing-svc-events-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "search-indexing-service-topic-processor"
  topic_id                    = module.retrieval-search-indexing-topic.topic_id
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
  pull_config = {
    message_retention_duration   = "604800s" # 7 days
    retain_acked_messages        = false
    ack_deadline_seconds         = 20
    expiration_policy_ttl        = "2678400s"
    retry_policy_minimum_backoff = "3s"
    enable_message_ordering      = true
  }
}

# points to env name SCHEMA_INGESTION_REQUESTS_TOPIC_PROCESSOR_SUBSCRIPTION_NAME
module "schema-ingestion-requests-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "schema-ingestion-requests-topic-processor"
  topic_id                    = module.retrieval-search-indexing-topic.topic_id
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
  pull_config = {
    message_retention_duration   = "604800s" # 7 days
    retain_acked_messages        = false
    ack_deadline_seconds         = 20
    expiration_policy_ttl        = "2678400s"
    retry_policy_minimum_backoff = "3s"
    enable_message_ordering      = true
  }
}

# SEARCH_INDEXING_SERVICE_GCS_PRODUCT_CATALOG_FILES_TOPIC_PROCESSOR_SUBSCRIPTION_NAME
module "search-indexing-svc-gcs-events-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "gcs-product-catalog-files-topic-processor"
  topic_id                    = local.product_catalog_files_inbound_pubsub_topic_id
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
  pull_config = {
    message_retention_duration   = "604800s" # 7 days
    retain_acked_messages        = false
    ack_deadline_seconds         = 20
    expiration_policy_ttl        = "2678400s"
    retry_policy_minimum_backoff = "3s"
    enable_message_ordering      = true
  }
}

module "search-indexing-svc-org-config-events-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "search-indexing-svc-org-config-events-processor"
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

module "search-indexing-svc-org-events-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "search-indexing-svc-org-events-processor"
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

module "retrieval-search-indexing-topic-permissions" {
  source                       = "../../../modules/create_pubsub_sa_role"
  region                       = var.region
  project_id                   = var.project_id
  service_account_email        = google_service_account.service_account.email
  service_account_service_name = var.service_name
  topic_name                   = module.retrieval-search-indexing-topic.topic_name
  deadletter_topic_name        = null
}

module "service" {
  source             = "../../../modules/create_gke_grpc_service"
  number_of_replicas = local.hpa_idle_number_of_replicas
  profiling_enabled  = var.environment == "dev" ? false : false
  container_command  = ["python3"]
  container_command_args = [
    "spiffy/service/retrieval/search_indexing/__main__.py"
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
  limits_cpus                                = 4
  limits_memory                              = "8Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 4
  requests_memory                            = "8Gi"
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
      service_name = "spiffy.service.retrieval.search.SearchIndexingService"
      port         = local.container_port
    }
    initial_delay_seconds = 10
    period_seconds        = 5
    timeout_seconds       = 10
    success_threshold     = 1
    failure_threshold     = 3
  }
  readiness_probe = {
    grpc = {
      service_name = "spiffy.service.retrieval.search.SearchIndexingService"
      port         = local.container_port
    }
    initial_delay_seconds = 10
    period_seconds        = 5
    timeout_seconds       = 10
    success_threshold     = 1
    failure_threshold     = 3
  }
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
      name  = "GOOGLE_PROJECT_NUMBER"
      value = var.project_number
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "SEARCH_INDEXING_PUBSUB_TOPIC_ID"
      value = module.retrieval-search-indexing-topic.topic_id
    },
    {
      name  = "PRODUCT_CATALOG_FILES_INBOUND_PUBSUB_TOPIC_ID"
      value = local.product_catalog_files_inbound_pubsub_topic_id
    },
    {
      name  = "SEARCH_INDEXING_MAX_WORKERS"
      value = 9 # our plan with zenrows has 10 max concurrent requests limit
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
      name      = "STATSIG_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_api_key.secret_data
      sensitive = true
    },
    {
      name  = "GOOGLE_PUBSUB_FLOW_CONTROL_MAX_MESSAGES"
      value = "1" # Ensure one message at a time per replica
    },
    {
      name  = "GOOGLE_PUBSUB_USE_THREAD_SCHEDULER"
      value = "true"
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
      name  = "SLACK_APP_ENG_ALERTS_WEBHOOK_URL"
      value = data.google_secret_manager_secret_version.slack_app_eng_alerts_webhook_url.secret_data
    },
    {
      name  = "ORG_EVENTS_TOPIC_ID"
      value = "projects/${var.project_id}/topics/cdc-main-db.public.organizations"
    },
    {
      name  = "ORG_CONFIG_EVENTS_TOPIC_ID"
      value = "projects/${var.project_id}/topics/cdc-main-db.public.organizations_config"
    },
    {
      name  = "DEFAULT_TEMPORAL_ACTIVITY_HEARTBEAT_TIMEOUT"
      value = "301" # 5 minutes in seconds
    },
    {
      name  = "TEXT_EMBEDDINGS_ENDPOINT_URL"
      value = var.text_embed_endpoint_url
    },
    {
      name  = "SEARCH_INDEXING_SVC_ORG_EVENTS_PROCESSOR_SUBSCRIPTION_ID"
      value = module.search-indexing-svc-org-events-processor.subscription_id
    },
    {
      name  = "SEARCH_INDEXING_SVC_ORG_EVENTS_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.search-indexing-svc-org-events-processor.subscription_name
    },
    {
      name  = "SEARCH_INDEXING_SVC_ORG_CONFIG_EVENTS_PROCESSOR_SUBSCRIPTION_ID"
      value = module.search-indexing-svc-org-config-events-processor.subscription_id
    },
    {
      name  = "SEARCH_INDEXING_SVC_ORG_CONFIG_EVENTS_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.search-indexing-svc-org-config-events-processor.subscription_name
    },
    {
      name  = "SEARCH_INDEXING_SERVICE_GCS_PRODUCT_CATALOG_FILES_TOPIC_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.search-indexing-svc-gcs-events-processor.subscription_name
    },
    {
      name  = "SEARCH_INDEXING_SERVICE_GCS_PRODUCT_CATALOG_FILES_TOPIC_PROCESSOR_SUBSCRIPTION_ID"
      value = module.search-indexing-svc-gcs-events-processor.subscription_id
    },
    {
      name  = "SEARCH_INDEXING_SERVICE_TOPIC_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.search-indexing-svc-events-processor.subscription_name
    },
    {
      name  = "SEARCH_INDEXING_SERVICE_TOPIC_PROCESSOR_SUBSCRIPTION_ID"
      value = module.search-indexing-svc-events-processor.subscription_id
    },
    {
      name  = "SCHEMA_INGESTION_PUBSUB_TOPIC_ID"
      value = module.retrieval-search-indexing-topic.topic_id
    },
    {
      name  = "SCHEMA_INGESTION_REQUESTS_TOPIC_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.schema-ingestion-requests-processor.subscription_name
    }
  ]
}

resource "random_integer" "randomized_start_time" {
  for_each = toset(local.reindex_merchants)
  min      = 0
  max      = 12
}

# batch index merchants
resource "google_cloud_scheduler_job" "cloud_scheduler_job_merchants_reindex" {
  depends_on  = [random_integer.randomized_start_time]
  count       = length(local.reindex_merchants)
  name        = "partner-products-reindex-${local.reindex_merchants[count.index]}"
  description = "Products Reindexing for ${local.reindex_merchants[count.index]}"
  # PROD: Every 3 hours 
  # DEV: Every 6 hours
  schedule = var.environment == "prod" ? "0 */3 * * *" : "0 */6 * * *"
  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = module.retrieval-search-indexing-topic.topic_id
    data = base64encode(jsonencode({
      "type" : "reindex",
      "org_short_name" : local.reindex_merchants[count.index]
    }))
  }
}

resource "google_project_iam_member" "secret_manager_access" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcs_access" {
  role_id     = "spiffy.searchIdxSvcGcsRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "GCS Role for ${var.service_name} service"
  description = "Terraform Managed - GCS Role for ${var.service_name} service"
  permissions = [
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
    "storage.objects.delete"

  ]
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

resource "google_project_iam_member" "iam_member_for_custom_role_gcs_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_gcs_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow GCS access to specific buckets"
    description = "Terraform Managed - Allow GCS access to data ingestion pipeline buckets"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-data-ingestion-pipeline-${var.environment}") ||
resource.name.startsWith("projects/_/buckets/spiffy-product-catalogs-receipts-${var.environment}")
EXPR
  }
}

module "logs-anomalies-monitoring" {
  source          = "../../../modules/create_dd_logs_anomalies_monitor"
  environment     = var.environment
  monitor_name    = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name    = var.service_name
  priority        = 2
  team            = var.team
  chapter         = var.chapter
  additional_tags = []
}

module "service_keda_horizontal_pod_autoscaler_prod_catalog_ingestion_queue" {
  source = "../../../modules/create_gke_hpa_keda_temporal"
  depends_on = [
    module.service
  ]

  environment                      = var.environment
  max_replica_count                = local.hpa_max_number_of_replicas
  min_replica_count                = local.hpa_min_number_of_replicas
  idle_replica_count               = local.hpa_idle_number_of_replicas
  namespace                        = var.gke_cluster_namespace
  project_id                       = var.project_id
  scale_target_ref                 = module.service.kubernetes_deployment_target_ref
  scaled_object_name               = "${var.service_name}-scaledobject"
  cool_down_period_seconds         = 600
  project_number                   = var.project_number
  service_account_name             = module.service.kubernetes_service_account
  queue_activation_query_value     = "0"
  queue_target_value               = "2"
  temporal_host                    = var.temporal_host
  temporal_namespace               = var.temporal_namespace
  temporal_task_queue_name         = "product_catalog_ingestion_task_queue"
}
