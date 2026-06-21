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
  number_of_replicas = 1
  container_port     = 8080
  service_port       = 9341
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "anthropic-api-key" {
  secret  = "anthropic-api-key"
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

data "google_secret_manager_secret_version" "spiffy-api-dev-secret" {
  secret  = "spiffy-api-dev-env-secret"
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

data "google_secret_manager_secret_version" "datadog_api_key" {
  secret  = "datadog_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog_app_key" {
  secret  = "datadog_app_key"
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
  role_id     = "spiffy.faqScrapeWorkerSvcCloudSqlRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ]
}

resource "google_project_iam_member" "iam_member_for_custom_role_cloudsql_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_cloudsql_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow cloudsql access"
    description = "Terraform Managed - Allow cloudsql access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/instances/${var.cloudsql_instance_name}")
EXPR
  }
}

module "service" {
  source             = "../../../modules/create_gke_grpc_service"
  number_of_replicas = local.number_of_replicas
  container_command  = ["python3"]
  container_command_args = [
    "-m",
    "spiffy.service.api.main.tools.run_faq_scrape_workers"
  ]
  container_dns_label                        = var.service_name
  container_port                             = local.container_port
  docker_image                               = var.docker_image
  docker_image_tag                           = var.docker_image_tag
  enable_service_directory_registry          = false
  service_directory_namespace_id             = null
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
  liveness_probe  = null
  readiness_probe = null
  env = [
    {
      name  = "LOGLEVEL"
      value = "INFO"
    },
    {
      name  = "ENV"
      value = var.environment
    },
    {
      name  = "POSTGRES_USER"
      value = "maindbuser"
    },
    {
      name  = "POSTGRES_HOSTNAME"
      value = "127.0.0.1"
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
      value = var.region
    },
    {
      name      = "ANTHROPIC_API_KEY"
      value     = data.google_secret_manager_secret_version.anthropic-api-key.secret_data
      sensitive = true
    },
    {
      name      = "ZENROWS_API_KEY"
      value     = data.google_secret_manager_secret_version.zenrows-api-key.secret_data
      sensitive = true
    },
    {
      name  = "TEMPORAL_HOST"
      value = var.temporal_host
    },
    {
      name      = "TEMPORAL_API_KEY"
      value     = data.google_secret_manager_secret_version.temporal-api-key.secret_data
      sensitive = true
    },
    {
      name      = "SPIFFY_API_KEY_DEV"
      value     = data.google_secret_manager_secret_version.spiffy-api-dev-secret.secret_data
      sensitive = true
    },
    {
      name  = "SLACK_APP_ENG_ALERTS_WEBHOOK_URL"
      value = data.google_secret_manager_secret_version.slack_app_eng_alerts_webhook_url.secret_data
    },
    {
      name      = "DD_API_KEY"
      value     = data.google_secret_manager_secret_version.datadog_api_key.secret_data
      sensitive = true
    },
    {
      name      = "DD_APP_KEY"
      value     = data.google_secret_manager_secret_version.datadog_app_key.secret_data
      sensitive = true
    },
    {
      name  = "DD_SITE"
      value = var.datadog_site
    },
    {
      name  = "DD_SERVICE"
      value = "faq-scrape-worker"
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
      name  = "PYTHONUNBUFFERED"
      value = "1"
    },
  ]
  team    = var.team
  chapter = var.chapter
}
