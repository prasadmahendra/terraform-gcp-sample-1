locals {
  min_instance_count = var.environment == "prod" ? 1 : 1
  max_instance_count = var.environment == "prod" ? 1 : 1
}

data "google_secret_manager_secret_version" "datadog_client_token_for_commerce_chat" {
  secret  = "datadog_client_token_for_commerce_chat"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog_app_id_for_commerce_chat" {
  secret  = "datadog_app_id_for_commerce_chat"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude_api_key" {
  secret  = "amplitude-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_client_key" {
  secret  = "statsig_client_key"
  project = var.project_id
}

# spiffy-commerce-chat-api-keys
data "google_secret_manager_secret_version" "spiffy-commerce-chat-api-keys" {
  secret  = "spiffy-commerce-chat-api-keys"
  project = var.project_id
  version = "latest"
}

module "service" {
  source           = "../../../modules/create_cloudrun_job"
  environment      = var.environment
  docker_image     = var.docker_image
  docker_image_tag = var.docker_image_tag
  name             = var.service_name
  region           = var.region
  project_id       = var.project_id
  docker_command   = null
  vpc_name         = var.vpc_name
  subnet_name      = var.subnet_name
  allow_vpc_access = false # No VPC access (essentially this runs in the DMZ)
  vpc_egress       = "PRIVATE_RANGES_ONLY"
  cpu_limit        = "8000m"
  memory_limit     = "32Gi"
  ports = [
    {
      name           = "http1",
      container_port = 3000
    }
  ]
  env = [
    {
      name = "VITE_DATADOG_APP_ID"
      value_source = {
        secret_key_ref = {
          secret  = data.google_secret_manager_secret_version.datadog_app_id_for_commerce_chat.secret
          version = data.google_secret_manager_secret_version.datadog_app_id_for_commerce_chat.version
        }
      }
      sensitive = true
    },
    {
      name = "VITE_DATADOG_CLIENT_TOKEN"
      value_source = {
        secret_key_ref = {
          secret  = data.google_secret_manager_secret_version.datadog_client_token_for_commerce_chat.secret
          version = data.google_secret_manager_secret_version.datadog_client_token_for_commerce_chat.version
        }
      }
      sensitive = true
    },
    {
      name = "VITE_AMPLITUDE_API_KEY"
      value_source = {
        secret_key_ref = {
          secret  = data.google_secret_manager_secret_version.amplitude_api_key.secret
          version = data.google_secret_manager_secret_version.amplitude_api_key.version
        }
      }
      sensitive = true
    },
    {
      name  = "VITE_DATA_RESIDENCY"
      value = "us"
    },
    {
      name  = "VITE_SPIFFY_CDN_URL"
      value = "https://cdn.spiffy.ai/other"
    },
    {
      name  = "VITE_DATADOG_INCLUDE"
      value = "false"
    },
    {
      name = "VITE_STATSIG_CLIENT_KEY"
      value_source = {
        secret_key_ref = {
          secret  = data.google_secret_manager_secret_version.statsig_client_key.secret
          version = data.google_secret_manager_secret_version.statsig_client_key.version
        }
      }
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    }
  ]
  is_public             = true
  datadog_api_key       = var.datadog_api_key
  datadog_site          = var.datadog_site
  datadog_trace_enabled = var.datadog_trace_enabled
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
