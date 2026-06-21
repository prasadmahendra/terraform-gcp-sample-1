terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  number_of_replicas = var.environment == "prod" ? 1 : 1
  container_port     = 8080
  service_port       = 9330
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "openai-api-key" {
  secret  = "openai-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role_sql" {
  role_id     = "spiffy.roleForService_CommerceDemoApi"
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

resource "google_project_iam_member" "service_account_for_cloud_run_custom_role_member" {
  project = var.project_id
  role    = google_project_iam_custom_role.google_project_iam_custom_role_sql.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

module "service" {
  source                 = "../../../modules/create_gke_http_service"
  container_command      = ["ddtrace-run"]
  container_command_args = [
    "python3",
    "spiffy/service/commerce_demo/__main__.py"
  ]
  container_dns_label               = var.service_name
  container_port                    = local.container_port
  docker_image                      = var.docker_image
  docker_image_tag                  = var.docker_image_tag
  enable_service_directory_registry = false
  environment                       = var.environment
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    id         = google_service_account.service_account.id
    account_id = google_service_account.service_account.account_id
  }
  gpu_accelerator_type         = null
  is_public                    = true
  kubernetes_namespace         = var.gke_cluster_namespace
  managed_ssl_certificate_name = var.managed_ssl_certificate_name
  number_of_replicas           = local.number_of_replicas
  persistent_volumes           = []
  project_id                   = var.project_id
  project_number               = var.project_number
  limits_cpus                  = 1
  limits_memory                = "1Gi"
  limits_nvidia_gpus           = null
  requests_cpus                = 0.5
  requests_memory              = "512Mi"
  requests_nvidia_gpus         = null
  service_name                 = var.service_name
  service_port                 = local.service_port
  apm_enabled                  = true
  service_fqdn                 = var.domain_name_public
  private_dns_zone_name        = var.dns_zone_name_private
  public_dns_zone_name         = var.dns_zone_name_public
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
      name      = "POSTGRES_PASSWORD"
      value     = data.google_secret_manager_secret_version.cloudsql-maindb-maindb-password.secret_data
      sensitive = true
    },
    {
      name      = "LLM_API_KEY"
      value     = data.google_secret_manager_secret_version.openai-api-key.secret_data
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
