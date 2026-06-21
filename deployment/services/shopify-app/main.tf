# Further reading:
# https://shopify.dev/docs/apps/launch/deployment/deploy-web-app/deploy-to-hosting-service

locals {
  domain_name_public = var.domain_name_public
  min_instance_count = var.environment == "prod" ? 1 : 1
  max_instance_count = var.environment == "prod" ? 2 : 1
}

data "google_secret_manager_secret_version" "shopify-app-spiffy-ai-analytics-client-id" {
  secret  = "shopify-app-spiffy-ai-analytics-client-id"
  project = var.project_id
}

data "google_secret_manager_secret_version" "shopify-app-spiffy-ai-analytics-client-secret" {
  secret  = "shopify-app-spiffy-ai-analytics-client-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-api-dev-secret" {
  secret  = "spiffy-api-dev-env-secret"
  project = var.project_id
}

# TODO: Scope down the API key used here! too broad!
data "google_secret_manager_secret_version" "spiffy-api-key" {
  secret  = "spiffy-api-key"
  project = var.project_id
}

module "service" {
  source                           = "../../../modules/create_cloudrun_service"
  environment                      = var.environment
  min_instance_count               = local.min_instance_count
  max_instance_count               = local.max_instance_count
  docker_image                     = var.docker_image
  docker_image_tag                 = var.docker_image_tag
  name                             = var.service_name
  region                           = var.region
  project_id                       = var.project_id
  docker_command                   = null
  vpc_name                         = var.vpc_name
  subnet_name                      = var.subnet_name
  allow_vpc_access                 = false # No VPC access (essentially this runs in the DMZ)
  vpc_egress                       = "PRIVATE_RANGES_ONLY"
  domain_name_public               = var.domain_name_public
  dns_zone_name_public             = var.dns_zone_name_public
  dns_zone_name_private            = var.dns_zone_name_private
  startup_probe_port               = 3000
  liveness_probe_path              = null
  cpu_idle                         = true
  cpu_limit                        = "1000m"
  memory_limit                     = "1Gi"
  max_instance_request_concurrency = 80
  ports                            = [
    {
      name           = "http1",
      container_port = 3000
    }
  ]
  env = [
    {
      name  = "SHOPIFY_API_KEY"
      value_source = {
        secret_key_ref = {
          secret = data.google_secret_manager_secret_version.shopify-app-spiffy-ai-analytics-client-id.secret
          version = data.google_secret_manager_secret_version.shopify-app-spiffy-ai-analytics-client-id.version
        }
      }
      sensitive = true
    },
    {
      name  = "SHOPIFY_API_SECRET"
      value_source = {
        secret_key_ref = {
          secret = data.google_secret_manager_secret_version.shopify-app-spiffy-ai-analytics-client-secret.secret
          version = data.google_secret_manager_secret_version.shopify-app-spiffy-ai-analytics-client-secret.version
        }
      }
      sensitive = true
    },
    {
      name  = "SCOPES"
      value = "read_customer_events,read_pixels,read_products,write_pixels"
    },
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name = "SHOPIFY_APP_URL"
      value = "https://${var.domain_name_public}"
    },
    {
      name  = "SPIFFY_API_URL"
      value = var.environment == "dev" ? "https://api.dev.spiffy.ai" : "https://api.spiffy.ai"
    },
    {
      name  = "SPIFFY_ORG_API_KEY"
      value_source = {
        secret_key_ref = {
          secret = data.google_secret_manager_secret_version.spiffy-api-key.secret
          version = data.google_secret_manager_secret_version.spiffy-api-key.version
        }
      }
      sensitive = true
    },
    {
      name  = "ENVIVE_API_URL_PROD"
      value = "https://api.spiffy.ai"
    },
    {
      name  = "ENVIVE_ORG_API_KEY_PROD"
      value_source = {
        secret_key_ref = {
          secret = data.google_secret_manager_secret_version.spiffy-api-key.secret
          version = data.google_secret_manager_secret_version.spiffy-api-key.version
        }
      }
      sensitive = true
    },
    {
      name  = "ENVIVE_API_URL_DEV"
      value = "https://api.dev.spiffy.ai"
    },
    {
      name      = "ENVIVE_ORG_API_KEY_DEV"
      value     = data.google_secret_manager_secret_version.spiffy-api-dev-secret.secret_data
      sensitive = true
    },
  ]
  is_public             = true
  datadog_api_key       = var.datadog_api_key
  datadog_site          = var.datadog_site
  datadog_trace_enabled = var.datadog_trace_enabled
}

module "logs-anomalies-monitoring" {
  count = 0
  source       = "../../../modules/create_dd_logs_anomalies_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name = var.service_name
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}
