terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  number_of_replicas = var.environment == "prod" ? 2 : 1
  container_port     = 8080
  service_port       = 9130
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

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
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

resource "google_project_iam_custom_role" "iam_custom_role_for_service_cloudsql_access" {
  role_id     = "spiffy.simonDataStreamsSvcCloudSqlRole_${random_string.suffix.result}"
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

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bq_access" {
  role_id     = "spiffy.simonDataStreamsSvcBigQueryRole_${random_string.suffix.result}"
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

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bt_access" {
  role_id = "spiffy.simonDataStreamsSvcBigTableRole_${random_string.suffix.result}"
  project = var.project_id
  title   = "Role for ${var.service_name} service"
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

module "simondata-streams-service-topic-permissions" {
  source                       = "../../../modules/create_pubsub_sa_role"
  region                       = var.region
  project_id                   = var.project_id
  service_account_email        = google_service_account.service_account.email
  service_account_service_name = var.service_name
  topic_name                   = var.simondata_intake_topic_id
  deadletter_topic_name        = var.simondata_intake_topic_id
}

module "simondata-streams-processor" {
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "simondata-streams-processor"
  topic_id                    = var.simondata_intake_topic_id
  project_id                  = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration  = "604800s" # 7 days
  with_dead_letter_queue      = true
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
resource.name.startsWith("projects/${var.project_id}/datasets/cdp_datastreams")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_bt_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_bt_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_bigtable_table_iam_member" "iam_custom_role_for_service_bt_access" {
  count = length(var.cdp_streams_bigtable_events_table_ids)
  table    = var.cdp_streams_bigtable_events_table_ids[count.index]
  instance = var.cdp_streams_bigtable_instance_id
  role     = google_project_iam_custom_role.iam_custom_role_for_service_bt_access.id
  member   = "serviceAccount:${google_service_account.service_account.email}"
}

module "service" {
  source             = "../../../modules/create_gke_grpc_service"
  number_of_replicas = local.number_of_replicas
  profiling_enabled  = var.environment == "dev" ? false : false
  container_command = ["python3"]
  container_command_args = [
    "spiffy/service/cdp/simondata/streams_processor/__main__.py"
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
  persistent_volumes = []
  project_id                                 = var.project_id
  project_number                             = var.project_number
  limits_cpus                                = 1
  limits_memory                              = "2Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 1
  requests_memory                            = "512Mi"
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
      service_name = "spiffy.service.simondata.simondata_intake.SimonDataStreamsProcessor"
      port         = local.container_port
    }
    initial_delay_seconds = 10
    period_seconds        = 5
    timeout_seconds       = 3
    success_threshold     = 1
    failure_threshold     = 3
  }
  readiness_probe = {
    grpc = {
      service_name = "spiffy.service.simondata.simondata_intake.SimonDataStreamsProcessor"
      port         = local.container_port
    }
    initial_delay_seconds = 10
    period_seconds        = 5
    timeout_seconds       = 3
    success_threshold     = 1
    failure_threshold     = 3
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
      name  = "SIMONDATA_PUBSUB_TOPIC_ID"
      value = var.simondata_intake_topic_id
    },
    {
      name  = "SIMONDATA_STREAMS_PROCESSOR_SUBSCRIPTION_NAME"
      value = module.simondata-streams-processor.subscription_name
    },
    {
      name  = "SIMONDATA_STREAMS_PROCESSOR_SUBSCRIPTION_ID"
      value = module.simondata-streams-processor.subscription_id
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
      name  = "SIMONDATA_BIGQUERY_TABLE_ID"
      value = var.persistence_bigquery_table_id
    },
    {
      name  = "CDP_STREAMS_BIGTABLE_INSTANCE_ID"
      value = var.cdp_streams_bigtable_instance_id
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
      name = "ENABLE_AGGREGATE_USER_EVENTS_TRACKING"
      value = "false"
    }
  ]
}

module "service_keda_horizontal_pod_autoscaler" {
  source = "../../../modules/create_gke_hpa_keda_pubsub"
  depends_on = [
    module.service
  ]

  environment                     = var.environment
  max_replica_count               = var.environment == "prod" ? 3 : 2
  min_replica_count               = 0 # cool down to zero when not in use
  namespace                       = var.gke_cluster_namespace
  project_id                      = var.project_id
  scale_target_ref                = module.service.kubernetes_deployment_target_ref
  scaled_object_name              = "${var.service_name}-scaledobject"
  subscription_id                 = module.simondata-streams-processor.subscription_id
  subscription_target_per_replica = "10"
  subscription_activation_value   = "0"
  subscription_time_horizon       = "2m"
  cool_down_period_seconds        = 300
  project_number                  = var.project_number
  service_account_name            = module.service.kubernetes_service_account
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