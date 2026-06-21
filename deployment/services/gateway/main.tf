locals {
  min_instance_count = var.environment == "prod" ? 2 : 1
  max_instance_count = var.environment == "prod" ? 3 : 1
}

module "service" {
  source             = "../../../modules/create_cloudrun_service"
  min_instance_count = local.min_instance_count
  max_instance_count = local.max_instance_count
  docker_image       = var.docker_image
  docker_image_tag   = var.docker_image_tag
  name               = var.service_name
  region             = var.region
  project_id         = var.project_id
  docker_command     = [
    "/app/datadog-init",
    "/dd_tracer/python/bin/ddtrace-run",
    "python",
    "spiffy/service/examples/gql_gateway/main/application/a_run_server.py"
  ]
  vpc_name                         = var.vpc_name
  subnet_name                      = var.subnet_name
  allow_vpc_access                 = true
  vpc_egress                       = "PRIVATE_RANGES_ONLY"
  startup_probe_port               = 8080
  cpu_idle                         = true
  cpu_limit                        = "500m"
  memory_limit                     = "512Mi"
  max_instance_request_concurrency = 1
  ports                            = [
    {
      name           = "http1",
      container_port = 8080
    }
  ]
  env = [
    {
      name  = "PYTHONPATH"
      value = "/opt/pymono"
    }
  ]
  is_public             = true
  domain_name_public    = var.domain_name_public
  dns_zone_name_private = null
  dns_zone_name_public  = var.dns_zone_name
  datadog_api_key       = var.datadog_api_key
  datadog_site          = var.datadog_site
  datadog_trace_enabled = var.datadog_trace_enabled
}