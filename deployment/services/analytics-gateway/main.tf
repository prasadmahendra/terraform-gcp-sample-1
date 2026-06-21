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

  hpa_idle_number_of_replicas       = var.environment == "prod" ? 12 : 2
  hpa_min_number_of_replicas        = var.environment == "prod" ? 13 : 3
  hpa_max_number_of_replicas        = var.environment == "prod" ? 30 : 8
  container_port                    = 8080
  service_port                      = 9350
  analytics_gateway_api_cpu_request = var.environment == "prod" ? 1 : 0.5
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

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role_sql" {
  role_id     = "spiffy.analyticsGatewayApiSvcSqlAccessRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - cloudsql access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ]
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

resource "google_project_iam_custom_role" "iam_custom_role_for_service_bt_access" {
  role_id     = "spiffy.analyticsGatewayBigTableRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
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

module "intake-topic" {
  source                 = "../../../modules/create_pubsub_topic"
  topic_name             = "analytics-intake-topic"
  project_id             = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration = "604800s" # 7 days
  with_dead_letter_queue = true
}

module "intake-topic-permissions" {
  source                       = "../../../modules/create_pubsub_sa_role"
  region                       = var.region
  project_id                   = var.project_id
  service_account_email        = google_service_account.service_account.email
  service_account_service_name = var.service_name
  topic_name                   = module.intake-topic.topic_name
  deadletter_topic_name        = null
}

module "service" {
  source            = "../../../modules/create_gke_http_service"
  environment       = var.environment
  service_name      = var.service_name
  project_id        = var.project_id
  region            = var.region
  subnet            = var.subnet
  profiling_enabled = var.environment == "dev" ? false : false
  container_command = ["ddtrace-run"]
  container_command_args = [
    "python3",
    "spiffy/service/gateways/analytics_gateway/__main__.py"
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
    initial_delay_seconds = 25
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
    initial_delay_seconds = 25
    period_seconds        = 5
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 5
  }
  project_number                             = var.project_number
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  is_public                                  = true
  kubernetes_namespace                       = var.gke_cluster_namespace
  managed_ssl_certificate_name               = var.managed_ssl_certificate_name
  number_of_replicas                         = local.hpa_idle_number_of_replicas
  persistent_volumes                         = []
  limits_cpus                                = local.analytics_gateway_api_cpu_request
  limits_memory                              = "1Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = local.analytics_gateway_api_cpu_request
  requests_memory                            = "1Gi"
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
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
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
      name  = "CDP_STREAMS_BIGTABLE_INSTANCE_ID"
      value = var.cdp_streams_bigtable_instance_id
    },
    {
      name = "ANALYTICS_STREAMS_PUBSUB_TOPIC_ID"
      value = module.intake-topic.topic_id
    }
  ]
}

module "logs-anomalies-monitoring" {
  source          = "../../../modules/create_dd_logs_anomalies_monitor"
  environment     = var.environment
  monitor_name    = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name    = var.service_name
  team            = var.team
  chapter         = var.chapter
  additional_tags = []
  priority        = 2
}

module "service_keda_horizontal_pod_autoscaler" {
  source = "../../../modules/create_gke_hpa_keda_datadog"
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
  cool_down_period_seconds         = 300
  project_number                   = var.project_number
  service_account_name             = module.service.kubernetes_service_account
  datadog_metric_name              = "waitress-queue-depth-analytics-gateway"
  datadog_metric_namespace         = var.gke_cluster_namespace
  datadog_metric_query             = "ewma_5(sum:python.waitress.queue{env:${var.environment}, service:-analytics-gateway}.weighted())"
  datadog_activation_query_value   = "0"
  datadog_target_value             = "2"
  datadog_age_time_window_seconds  = "300"
  datadog_use_cluster_agent_proxy  = "false"
  datadog_metric_unavailable_value = "0"
}
