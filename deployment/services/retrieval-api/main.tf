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
  service_port       = 9320
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-auth-token-signing-secret" {
  secret  = "spiffy-auth-token-signing-secret"
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

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

resource "google_service_account" "retrival-api-streams-processor-gsa" {
  account_id   = "${substr(var.service_name, 0, 16)}-${lower(random_string.suffix.result)}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role" {
  role_id     = "spiffy.roleForService_RetrievalApiIntake_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ]
}

resource "google_project_iam_member" "service_account_for_cloud_run_custom_role_member" {
  project = var.project_id
  role    = google_project_iam_custom_role.google_project_iam_custom_role.id
  member  = "serviceAccount:${google_service_account.retrival-api-streams-processor-gsa.email}"
}

module "service" {
  source            = "../../../modules/create_gke_http_service"
  profiling_enabled = var.environment == "dev" ? false : false
  container_command = ["ddtrace-run"]
  container_command_args = [
    "python3",
    "spiffy/service/retrieval/retrieval_api/__main__.py"
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
    email      = google_service_account.retrival-api-streams-processor-gsa.email
    id         = google_service_account.retrival-api-streams-processor-gsa.id
    account_id = google_service_account.retrival-api-streams-processor-gsa.account_id
  }
  is_public                                  = false
  service_fqdn                               = var.domain_name_public
  public_dns_zone_name                       = var.dns_zone_name_public
  private_dns_zone_name                      = var.dns_zone_name_private
  kubernetes_namespace                       = var.gke_cluster_namespace
  number_of_replicas                         = local.number_of_replicas
  persistent_volumes = []
  project_id                                 = var.project_id
  project_number                             = var.project_number
  limits_cpus                                = 2
  limits_memory                              = "2Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 0.5
  requests_memory                            = "1Gi"
  requests_nvidia_gpus                       = null
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  service_name                               = var.service_name
  service_port                               = local.service_port
  apm_enabled                                = true
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
  managed_ssl_certificate_name = var.managed_ssl_certificate_name
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
      name  = "ENV"
      value = var.environment
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
      name      = "SPIFFY_USER_AUTH_TOKEN_SIGNING_SECRET"
      value     = data.google_secret_manager_secret_version.spiffy-auth-token-signing-secret.secret_data
      sensitive = true
    },
    {
      name      = "STATSIG_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_api_key.secret_data
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
}
