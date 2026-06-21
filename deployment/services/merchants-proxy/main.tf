locals {
  domain_name_public = var.domain_name_public
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
      name  = "CDN_PREFIX"
      value = "https://cdn.spiffy.ai/"
    },
    {
      name  = "CDN_FILE"
      value = "spiffy-commerce-chat-index-latest.js"
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
