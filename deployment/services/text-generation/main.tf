terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  text_generation_service_container_port                              = 8080
  text_generation_service_port                                        = 80
  number_of_replicas                                                  = var.number_of_replicas
}

#
# Runs the text embedding service
# https://github.com/huggingface/Google-Cloud-Containers/tree/main/examples/gke/tei-deployment
#

# Add this data source to fetch the API key from Secret Manager
data "google_secret_manager_secret_version" "huggingface-endpoint-access-token" {
  secret  = "huggingface-endpoint-access-token"
  project = var.project_id
}

module "text-generation-service" {
  source                                 = "../../../modules/create_gke_http_service"
  kubernetes_namespace                   = var.cluster_namespace
  service_name                           = var.service_name
  container_dns_label                    = var.service_name
  container_port                         = local.text_generation_service_container_port
  docker_image                           = var.docker_image
  docker_image_tag                       = var.docker_image_tag
  environment                            = var.environment
  service_port                           = local.text_generation_service_port
  number_of_replicas                     = local.number_of_replicas
  google_service_account_for_the_service = var.service_account
  subnet                                 = var.subnet
  region                                 = var.region

  persistent_volumes = []
  project_id     = var.project_id
  project_number = var.project_number
  liveness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.text_generation_service_container_port
      http_headers = [
        {
          name  = "Authorization"
          value = "Bearer ${data.google_secret_manager_secret_version.huggingface-endpoint-access-token.secret_data}"
        }
      ]
    }
    initial_delay_seconds = 20
    period_seconds        = 10
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 10
  }
  readiness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.text_generation_service_container_port
      http_headers = [
        {
          name  = "Authorization"
          value = "Bearer ${data.google_secret_manager_secret_version.huggingface-endpoint-access-token.secret_data}"
        }
      ]
    }
    initial_delay_seconds = 30
    period_seconds        = 10
    failure_threshold     = 2
    success_threshold     = 1
    timeout_seconds       = 10
  }
  # https://huggingface.co/docs/text-embeddings-inference/en/cli_arguments
  env = [
    {
      name  = "MODEL_ID"
      value = var.model_name
    },
    {
      name  = "JSON_OUTPUT"
      value = "true"
    },
    {
      name  = "DEPLOY_SOURCE"
      value = "UI_HF_VERIFIED_MODEL"
    },
    {
      name  = "NUM_SHARD"
      value = "1"
    },
    # {
    #   name      = "API_KEY"
    #   value     = data.google_secret_manager_secret_version.huggingface-endpoint-access-token.secret_data
    #   sensitive = true
    # },
    {
      name  = "PAYLOAD_LIMIT"
      value = "16777216"  # 16MB in bytes
    },
    {
      name  = "AUTO_TRUNCATE"
      value = "true"
    },
    {
      name  = "LOG_LEVEL"
      value = "WARN"
    }
  ]
  limits_cpus                       = var.cpu_alloc_max
  limits_memory                     = var.memory_alloc_max
  limits_nvidia_gpus                = var.gpu_accelerator_count
  requests_cpus                     = var.cpu_alloc_min
  requests_memory                   = var.memory_alloc_min
  requests_nvidia_gpus              = var.gpu_accelerator_count
  gpu_accelerator_type              = var.gpu_accelerator_type
  is_public                         = var.is_public
  enable_service_directory_registry = false
  service_directory_namespace_id    = var.service_directory_namespace_id
  managed_ssl_certificate_name      = var.managed_ssl_certificate_name
  service_fqdn                      = var.service_fqdn
  private_dns_zone_name             = var.private_dns_zone_name
  public_dns_zone_name              = var.public_dns_zone_name
  set_shm_to_memory                 = var.set_shm_to_memory
  apm_enabled                       = true
}

module "logs-monitoring" {
  count        = 0
  source       = "../../../modules/create_dd_logs_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} logs monitor (Managed by Terraform)"
  service_name = var.service_name
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}

module "logs-anomalies-monitoring" {
  source       = "../../../modules/create_dd_logs_anomalies_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name = var.service_name
  priority     = 2
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}
