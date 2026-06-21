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
  service_port       = 9110
  cdc_pub_sub_topic_id_list = [
    "projects/${var.project_id}/topics/cdc-main-db.public.organizations",
    "projects/${var.project_id}/topics/cdc-main-db.public.organizations_config",
    "projects/${var.project_id}/topics/cdc-main-db.public.iam_roles",
    "projects/${var.project_id}/topics/cdc-main-db.public.iam_user_roles",
    "projects/${var.project_id}/topics/cdc-main-db.public.iam_users"
  ]
  cdc_pub_sub_topic_id_list_clean = [
    "cdc-main-db.public.organizations",
    "cdc-main-db.public.organizations_config",
    "cdc-main-db.public.iam_roles",
    "cdc-main-db.public.iam_user_roles",
    "cdc-main-db.public.iam_users"
  ]
  cdc_pub_sub_topic_id_string_list = join(",", local.cdc_pub_sub_topic_id_list)
  # array list of pubsub topic names only - ex: cdc-main-db.public.organizations
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

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bq_access" {
  role_id     = "spiffy.cdcStreamsSvcBigQueryRole_${random_string.suffix.result}"
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
  role_id     = "spiffy.cdcStreamsSvcCloudSqlRole_${random_string.suffix.result}"
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

module "cdc-streams-service-topic-permissions" {
  source                       = "../../../modules/create_pubsub_sa_role"
  region                       = var.region
  project_id                   = var.project_id
  service_account_email        = google_service_account.service_account.email
  service_account_service_name = var.service_name
  topic_name                   = null
  deadletter_topic_name        = null
}

module "cdc-streams-processor" {
  count                       = length(local.cdc_pub_sub_topic_id_list)
  source                      = "../../../modules/create_pubsub_topic_subscription"
  subscription_name           = "${local.cdc_pub_sub_topic_id_list_clean[count.index]}-cdc-stream-sub"
  topic_id                    = local.cdc_pub_sub_topic_id_list[count.index]
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
resource.name.startsWith("projects/${var.project_id}/datasets/cdc_datastreams")
EXPR
  }
}

module "service" {
  source             = "../../../modules/create_gke_grpc_service"
  number_of_replicas = local.number_of_replicas
  profiling_enabled  = var.environment == "dev" ? false : false
  container_command = ["python3"]
  container_command_args = [
    "spiffy/service/cdc/streams_processor/__main__.py"
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
  limits_cpus                                = 2
  limits_memory                              = "2Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 2
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
      service_name = "spiffy.service.cdc.cdc_streams.CdcStreamsProcessor"
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
      service_name = "spiffy.service.cdc.cdc_streams.CdcStreamsProcessor"
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
      name  = "GOOGLE_PROJECT_NUMBER"
      value = var.project_number
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "CDC_BIGQUERY_TABLE_ID"
      value = var.persistence_bigquery_table_id
    },
    {
      name  = "CDC_STREAMS_PROCESSOR_INPUT_PUBSUB_TOPIC_IDS"
      value = local.cdc_pub_sub_topic_id_string_list # "projects/${var.project_id}/topics/cdc-main-db.public.organizations,projects/${var.project_id}/topics/cdc-main-db.public.organizations_config,projects/${var.project_id}/topics/cdc-main-db.public.iam_roles,projects/${var.project_id}/topics/cdc-main-db.public.iam_user_roles,projects/${var.project_id}/topics/cdc-main-db.public.iam_users"
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