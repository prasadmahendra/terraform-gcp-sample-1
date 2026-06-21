terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

locals {
  text_generation_service_container_port = 8002
  deep_health_sidecar_port               = 8003
  text_generation_service_port           = 80
  number_of_replicas                     = var.number_of_replicas
  enable_cloudsql_databases              = false  # Enable once we figure out how to get the job to exit the sidecar container on completion
  service_gcs_bucket_name                = var.service_gcs_bucket_name
  gcs_instance_capacity                  = var.environment == "prod" ? "1Ti" : "1Ti"
  health_probe_port                      = var.enable_deep_health_check ? local.deep_health_sidecar_port : local.text_generation_service_container_port
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

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa-${random_string.suffix.result}"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

# gcs role
resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcs_access" {
  role_id     = "spiffy.testJobGcsAccessRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} - gcs access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
  ]
}

# MountVolume.SetUp failed for volume "cdc-main-db-gcs-pv" : rpc error: code = PermissionDenied desc = failed to
# get GCS bucket "spiffy-cdc-states-dev": googleapi: Error 403: cdc-main-db-gsa@spiffy-ai-dev.iam.gserviceaccount.com does not have storage.objects.list
# access to the Google Cloud Storage bucket. Permission 'storage.objects.list' denied on resource (or it may not exist)., forbidden
resource "google_project_iam_member" "iam_member_for_custom_role_gcs_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_gcs_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow gcs access"
    description = "Terraform Managed - Allow gcs access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${local.service_gcs_bucket_name}")
EXPR
  }
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role_sql" {
  role_id     = "spiffy.testJobSqlAccessRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - cloudsql access"
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

module "service-gcs-bucket-pv" {
  source                            = "../../../modules/create_gke_gcs_volume"
  bucket_name                       = local.service_gcs_bucket_name
  environment                       = var.environment
  persistent_volume_capacity        = local.gcs_instance_capacity
  persistent_volume_claim_name      = "${var.service_name}-gcs-pvc-v2"
  persistent_volume_claim_namespace = var.gke_cluster_namespace
  persistent_volume_name            = "${var.service_name}-gcs-pv-v2"
  read_only                         = true
}

module "testing-job" {
  source               = "../../../modules/create_gke_job_service"
  kubernetes_namespace = var.gke_cluster_namespace
  service_name         = var.service_name
  container_dns_label  = var.service_name
  container_port       = local.text_generation_service_container_port
  docker_image         = var.docker_image
  docker_image_tag     = var.docker_image_tag
  environment          = var.environment
  service_port         = local.text_generation_service_port
  number_of_replicas   = local.number_of_replicas
  google_service_account_for_the_service = {
    id         = google_service_account.service_account.id
    email      = google_service_account.service_account.email
    account_id = google_service_account.service_account.account_id
  }

  container_command = var.container_command_override
  container_command_args = var.container_command_args_override
  sidecar_containers = var.enable_deep_health_check ? [
    {
      name              = "deep-health-check"
      image             = "${var.docker_image}:${var.docker_image_tag}"
      image_pull_policy = "IfNotPresent"
      command           = ["python3"]
      args              = ["./deep_health_check.py"]
      env = {
        VLLM_BASE_URL           = "http://localhost:${local.text_generation_service_container_port}/v1"
        HEALTH_CHECK_PORT       = tostring(local.deep_health_sidecar_port)
        HEALTH_CHECK_TIMEOUT    = "60"
        HEALTH_CHECK_MAX_TOKENS = "1000"
      }
      port     = local.deep_health_sidecar_port
      limits   = {}
      requests = {}
    }
  ] : []

  pod_annotations = {
    "ad.datadoghq.com/${var.service_name}.check_names"      = "[\"openmetrics\"]"
    "ad.datadoghq.com/${var.service_name}.init_configs"     = "[{}]"
    "ad.datadoghq.com/${var.service_name}.instances"        = "[{\"prometheus_url\": \"http://%%host%%:8002/metrics\", \"namespace\": \"vllm\", \"metrics\": [\"*\"]}]"
  }

  persistent_volumes = [
    {
      name                         = "spiffy-test-data-volume"
      mount_path                   = "/data/llm-service"
      read_only                    = true
      persistent_volume_claim_name = module.service-gcs-bucket-pv.persistent_volume_claim_name
    }
  ]
  project_id                        = var.project_id
  project_number                    = var.project_number
  liveness_probe                    = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.health_probe_port
      http_headers = null
    }
    initial_delay_seconds = 1500
    period_seconds        = 120
    failure_threshold     = 10
    success_threshold     = 1
    timeout_seconds       = 10
  }
  readiness_probe                   = {
    grpc = null
    http_get = {
      path = "/health"
      port = local.health_probe_port
      http_headers = null
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
  target_node_pool_name             = var.target_node_pool_name
  is_public                         = false
  enable_service_directory_registry = false
  service_directory_namespace_id    = var.service_directory_namespace_id
  managed_ssl_certificate_name      = var.managed_ssl_certificate_name
  service_fqdn                      = null
  private_dns_zone_name             = var.private_dns_zone_name
  public_dns_zone_name              = var.public_dns_zone_name
  set_shm_to_memory                 = true
  apm_enabled                       = true
  datadog_api_key                   = var.datadog_api_key
  datadog_app_key                   = var.datadog_app_key
  datadog_site                      = var.datadog_site
  cloudsql_databases                = local.enable_cloudsql_databases ? [
    {
      port                     = 5432
      instance_connection_name = var.database_connection_name
    }
  ] : []
  env = [
    {
      name  = "POSTGRES_USER"
      value = "maindbuser"
    },
    {
      name  = "POSTGRES_HOSTNAME"
      value = "127.0.0.1" # connect to SQL proxy via private IP
    },
    {
      name      = "POSTGRES_PASSWORD"
      value     = data.google_secret_manager_secret_version.cloudsql-maindb-maindb-password.secret_data
      sensitive = true
    },
    {
      name = "ORG_SHORT_NAME"
      value = "debug"
    },
    {
      name = "DATE"
      value = "20250127"
    }
  ]
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
