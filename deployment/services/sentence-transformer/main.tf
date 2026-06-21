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
  service_port       = 8080
}

resource "google_service_account" "sentence-transformer-api-streams-processor-gsa" {
  account_id   = "${substr(var.service_name, 0, 16)}-${lower(random_string.suffix.result)}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role" {
  role_id     = "spiffy.roleForService_SentenceTransformer_${random_string.suffix.result}"
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
  member  = "serviceAccount:${google_service_account.sentence-transformer-api-streams-processor-gsa.email}"
}

module "service" {
  source              = "../../../modules/create_gke_http_service"
  profiling_enabled   = var.environment == "dev" ? false : false
  container_command = []
  container_command_args = []
  container_dns_label = var.service_name
  container_port      = local.container_port
  docker_image        = "us-docker.pkg.dev/spiffy-prod/vertex-ai/sentence-transformers"
  docker_image_tag    = "py310-cu12.3-torch-2.2.0-transformers-4.38.1"
  subnet              = null
  region              = null
  enable_service_directory_registry = false
  environment                       = var.environment
  google_service_account_for_the_service = {
    email      = google_service_account.sentence-transformer-api-streams-processor-gsa.email
    id         = google_service_account.sentence-transformer-api-streams-processor-gsa.id
    account_id = google_service_account.sentence-transformer-api-streams-processor-gsa.account_id
  }
  is_public             = false
  service_fqdn          = var.domain_name_public
  public_dns_zone_name  = var.dns_zone_name_public
  private_dns_zone_name = var.dns_zone_name_private
  kubernetes_namespace  = var.gke_cluster_namespace
  number_of_replicas    = local.number_of_replicas
  persistent_volumes = []
  project_id            = var.project_id
  project_number        = var.project_number
  limits_cpus           = 2
  limits_memory         = "8Gi"
  limits_nvidia_gpus    = 1
  requests_cpus         = 1
  requests_memory       = "6Gi"
  requests_nvidia_gpus  = var.gpu_accelerator_count
  gpu_accelerator_type  = var.gpu_accelerator_type
  service_name          = var.service_name
  service_port          = local.service_port
  apm_enabled           = true
  liveness_probe = null
#   liveness_probe = {
#     grpc = null
#     http_get = {
#       path = "/health"
#       port = local.container_port
#     }
#     initial_delay_seconds = 5
#     period_seconds        = 5
#     failure_threshold     = 2
#     success_threshold     = 1
#     timeout_seconds       = 3
#   }
  readiness_probe = null
#   readiness_probe = {
#     grpc = null
#     http_get = {
#       path = "/health"
#       port = local.container_port
#     }
#     initial_delay_seconds = 5
#     period_seconds        = 5
#     failure_threshold     = 2
#     success_threshold     = 1
#     timeout_seconds       = 3
#   }
  cloudsql_databases = []
  managed_ssl_certificate_name = var.managed_ssl_certificate_name
  env = [
    {
      name  = "ENV"
      value = var.environment
    },
    {
      name  = "LOGLEVEL"
      value = "INFO"
    },
    {
      name = "AIP_HTTP_PORT"
      value = "8080"
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
