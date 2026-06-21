terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  llm_inference_service_container_port                        = 8002
  llm_inference_deep_health_sidecar_port                      = 8003
  llm_inference_service_port                                  = 80
  llm_inference_service_persistent_volume_data_dir_gcs_backed = "/data/llm-service"
  llm_inference_model_data_dir                                = local.llm_inference_service_persistent_volume_data_dir_gcs_backed
  number_of_replicas                                          = var.number_of_replicas
  health_probe_port                                           = var.enable_deep_health_check ? local.llm_inference_deep_health_sidecar_port : local.llm_inference_service_container_port
}

module "llm-inference-service" {
  source               = "../../../modules/create_gke_http_service"
  kubernetes_namespace = var.cluster_namespace
  service_name         = var.service_name
  container_dns_label  = var.service_name
  container_port       = local.llm_inference_service_container_port
  docker_image         = var.docker_image
  docker_image_tag     = var.docker_image_tag
  environment          = var.environment
  service_port                           = local.llm_inference_service_port
  number_of_replicas                     = local.number_of_replicas
  number_of_replicas_spot_capacity       = var.number_of_replicas_spot_capacity
  spot_capacity_compute_class            = var.spot_capacity_compute_class
  google_service_account_for_the_service = var.service_account
  progress_deadline_seconds              = 3600  # 1 hr for model loading
  pod_annotations = {
    "ad.datadoghq.com/${var.service_set_name}-${var.service_name_suffix}.check_names"  = "[\"openmetrics\"]"
    "ad.datadoghq.com/${var.service_set_name}-${var.service_name_suffix}.init_configs" = "[{}]"
    "ad.datadoghq.com/${var.service_set_name}-${var.service_name_suffix}.instances"    = "[{\"prometheus_url\": \"http://%%host%%:8002/metrics\", \"namespace\": \"vllm\", \"metrics\": [\"*\"]}]"
  }

  # Custom rolling update strategy for LLM inference services
  max_unavailable  = 1          # Keep at least N-1 pods running during rolling update
  pdb_min_available = local.number_of_replicas > 1 ? 1 : null  # Keep at least 1 pod alive during node drain

  persistent_volumes = [
    {
      name                         = "gcs-fuse-csi-static"
      mount_path                   = local.llm_inference_service_persistent_volume_data_dir_gcs_backed
      read_only                    = var.attached_persistent_volume_read_only
      persistent_volume_claim_name = var.persistent_volume_claim_name_gcs_backed
    }
  ]
  project_id        = var.project_id
  project_number    = var.project_number
  container_command = var.container_command_override != null && length(var.container_command_override) > 0 ? var.container_command_override : ["python"]
  container_command_args = concat(
    var.container_command_args_override != null && length(var.container_command_args_override) > 0 ? var.container_command_args_override :
    [
      "cli/start_vllm.py",
      "--config", "cli/configs/${var.model_config}",
      "--model", "${local.llm_inference_model_data_dir}/${var.model_name}",
      "--port", local.llm_inference_service_container_port
    ],
    var.additional_container_command_args
  )
  sidecar_containers = var.enable_deep_health_check ? [
    {
      name              = "deep-health-check"
      image             = "${var.docker_image}:${var.docker_image_tag}"
      image_pull_policy = "Always"
      command           = ["python3"]
      args              = ["./deep_health_check.py"]
      env = {
        VLLM_BASE_URL           = "http://localhost:${local.llm_inference_service_container_port}/v1"
        HEALTH_CHECK_PORT       = tostring(local.llm_inference_deep_health_sidecar_port)
        HEALTH_CHECK_TIMEOUT    = "10"
        HEALTH_CHECK_MAX_TOKENS = "1000"
      }
      port     = local.llm_inference_deep_health_sidecar_port
      limits   = {}
      requests = {}
    }
  ] : []
  liveness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.health_probe_port
    }
    initial_delay_seconds = 1500
    period_seconds        = 120
    failure_threshold     = 10
    success_threshold     = 1
    timeout_seconds       = 10
  }
  readiness_probe = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.health_probe_port
    }
    initial_delay_seconds = 120
    period_seconds        = 120
    failure_threshold     = 10
    success_threshold     = 1
    timeout_seconds       = 10
  }
  limits_cpus                       = var.cpu_alloc_max
  limits_memory                     = var.memory_alloc_max
  limits_nvidia_gpus                = var.gpu_accelerator_count
  requests_cpus                     = var.cpu_alloc_min
  requests_memory                   = var.memory_alloc_min
  requests_nvidia_gpus              = var.gpu_accelerator_count
  gpu_accelerator_type              = var.gpu_accelerator_type
  is_public                         = true
  enable_service_directory_registry = false
  service_directory_namespace_id    = var.service_directory_namespace_id
  managed_ssl_certificate_name      = var.managed_ssl_certificate_name
  service_fqdn                      = var.service_fqdn
  private_dns_zone_name             = var.private_dns_zone_name
  public_dns_zone_name              = var.public_dns_zone_name
  set_shm_to_memory                 = var.set_shm_to_memory
  apm_enabled                       = true
  enable_local_ssd                  = true
  gpu_nodepool                      = var.gpu_nodepool
  subnet                            = var.subnet
  region                            = var.region
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
