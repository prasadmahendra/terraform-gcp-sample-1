locals {
  min_instance_count = var.environment == "prod" ? 1 : 1
  max_instance_count = var.environment == "prod" ? 1 : 1
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
  cpu_limit        = "2000m"
  memory_limit     = "8Gi"
  ports = [
    {
      name           = "http1",
      container_port = 3000
    }
  ]
  env = []
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
