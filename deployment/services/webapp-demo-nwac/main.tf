locals {
  min_instance_count = var.environment == "prod" ? 1 : 1
  max_instance_count = var.environment == "prod" ? 1 : 1
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
  allow_vpc_access                 = true
  vpc_egress                       = "PRIVATE_RANGES_ONLY"
  domain_name_public               = var.domain_name_public
  dns_zone_name_public             = var.dns_zone_name_public
  dns_zone_name_private            = var.dns_zone_name_private
  startup_probe_port               = 3000
  liveness_probe_path              = null
  cpu_idle                         = true
  cpu_limit                        = "500m"
  memory_limit                     = "512Mi"
  max_instance_request_concurrency = 1
  ports                            = [
    {
      name           = "http1",
      container_port = 3000
    }
  ]
  env = [
    {
      name  = "REACT_APP_SPIFFY_API_KEY"
      value = "1234"
    },
    {
      name  = "REACT_APP_PROMPT_API_URL"
      value = "https://nwac-data.dev.spiffy.ai/latest_nwac_weather_forecast_prompt"
    },
    {
      name  = "REACT_APP_SPIFFY_API_BASE"
      value = "https://inference-chat.dev.spiffy.ai/v1"
    },
    {
      name  = "REACT_APP_SPIFFY_MODEL_NAME"
      value = "nwac-ep2step201_retrained"
    },
    {
      name  = "nwac-ep2step201_retrained"
      value = "https://inference-chat.dev.spiffy.ai/v1"
    }
  ]
  is_public             = true
  datadog_api_key       = var.datadog_api_key
  datadog_site          = var.datadog_site
  datadog_trace_enabled = var.datadog_trace_enabled
}
