terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  domain_name_public = var.domain_name_public
  number_of_replicas = var.environment == "prod" ? 2 : 1
  container_port     = 8080
  service_port       = 9300
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

module "simondata-intake-topic" {
  source                 = "../../../modules/create_pubsub_topic"
  topic_name             = "simondata-intake-topic"
  project_id             = var.project_id
  allowed_persistence_regions = [var.region]
  message_retention_duration = "604800s" # 7 days
  with_dead_letter_queue = true
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-sa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_cloudsql_access" {
  role_id     = "spiffy.segmentDataIntakeSvcCloudSqlRole_${random_string.suffix.result}"
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

module "simondata-intake-topic-permissions" {
  source                       = "../../../modules/create_pubsub_sa_role"
  region                       = var.region
  project_id                   = var.project_id
  service_account_email        = google_service_account.service_account.email
  service_account_service_name = var.service_name
  topic_name                   = module.simondata-intake-topic.topic_name
  deadletter_topic_name        = null
}

module "service" {
  source = "../../../modules/create_gke_http_service"
  container_command = ["python3"]
  container_command_args = [
    "spiffy/service/gateways/any_webhooks/__main__.py"
  ]
  container_dns_label               = var.service_name
  container_port                    = local.container_port
  docker_image                      = var.docker_image
  docker_image_tag                  = var.docker_image_tag
  enable_service_directory_registry = false
  environment                       = var.environment
  subnet                            = var.subnet
  region                            = var.region
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    id         = google_service_account.service_account.id
    account_id = google_service_account.service_account.account_id
  }
  is_public                                  = true
  service_fqdn                               = var.domain_name_public
  public_dns_zone_name                       = var.dns_zone_name_public
  private_dns_zone_name                      = var.dns_zone_name_private
  kubernetes_namespace                       = var.gke_cluster_namespace
  number_of_replicas                         = local.number_of_replicas
  persistent_volumes = []
  project_id                                 = var.project_id
  project_number                             = var.project_number
  limits_cpus                                = 2
  limits_memory                              = "1Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 0.5
  requests_memory                            = "512Mi"
  requests_nvidia_gpus                       = null
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  service_name                               = var.service_name
  service_port                               = local.service_port
  apm_enabled                                = false
  liveness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.container_port
    }
    initial_delay_seconds = 5
    period_seconds        = 5
    failure_threshold     = 2
    success_threshold     = 1
    timeout_seconds       = 3
  }
  readiness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.container_port
    }
    initial_delay_seconds = 5
    period_seconds        = 5
    failure_threshold     = 2
    success_threshold     = 1
    timeout_seconds       = 3
  }
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
      name  = "INTAKE_STREAM_PUBSUB_TOPIC_ID"
      value = module.simondata-intake-topic.topic_id
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
      name      = "STATSIG_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_api_key.secret_data
      sensitive = true
    }
  ]
  managed_ssl_certificate_name = var.managed_ssl_certificate_name
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