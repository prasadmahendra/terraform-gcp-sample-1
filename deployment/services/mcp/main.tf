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

# --- Secrets -----------------------------------------------------------------

data "google_secret_manager_secret_version" "cloudsql-maindb-maindb-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elastic-search-api-key" {
  secret  = "elastic-search-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "elasticsearch-cloud-id" {
  secret  = "elasticsearch_cloud_id"
  project = var.project_id
}

# Amplitude: per webapp-admin's pattern (TODO SPFY-2801), dev MCP uses the
# prod Amplitude credentials so it can surface real popular-questions data
# (dev Amplitude is sparsely populated). Prod uses its own.
data "google_secret_manager_secret_version" "amplitude-api-prod-key" {
  count   = var.environment == "dev" ? 1 : 0
  secret  = "amplitude-prod-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-prod-secret" {
  count   = var.environment == "dev" ? 1 : 0
  secret  = "amplitude-prod-api-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-key" {
  secret  = "amplitude-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-secret" {
  secret  = "amplitude-api-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-auth-token-signing-secret" {
  secret  = "spiffy-auth-token-signing-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "statsig_api_key" {
  secret  = "statsig_api_key"
  project = var.project_id
}

# Signs the 90s authorization-code JWTs the OAuth shim mints for Claude.ai's
# Custom Connector flow. Must be the same value across replicas (so any pod can
# verify a code another pod issued). Store in GCP Secret Manager — both
# spiffy-ai-dev and spiffy-prod projects — as a 32+ byte random hex string:
#   openssl rand -hex 32 | \
#     gcloud --project=<proj> secrets create mcp-oauth-signing-secret --data-file=-
data "google_secret_manager_secret_version" "mcp-oauth-signing-secret" {
  secret  = "mcp-oauth-signing-secret"
  project = var.project_id
}

# --- Service account ---------------------------------------------------------

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

# Read-only access to Cloud SQL Postgres (IAM maindb).
resource "google_project_iam_member" "service_account_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

# --- Workload ----------------------------------------------------------------

module "service" {
  source            = "../../../modules/create_gke_http_service"
  environment       = var.environment
  service_name      = var.service_name
  project_id        = var.project_id
  subnet            = var.subnet
  region            = var.region
  profiling_enabled = false
  container_command = ["ddtrace-run"]
  container_command_args = [
    "python3",
    "-m",
    "spiffy.service.mcp",
  ]
  container_dns_label               = var.service_name
  container_port                    = local.container_port
  docker_image                      = var.docker_image
  docker_image_tag                  = var.docker_image_tag
  enable_service_directory_registry = false
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    id         = google_service_account.service_account.id
    account_id = google_service_account.service_account.account_id
  }
  liveness_probe = {
    grpc = null
    http_get = {
      path = "/healthz"
      port = local.container_port
    }
    initial_delay_seconds = 15
    period_seconds        = 5
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 5
  }
  readiness_probe = {
    grpc = null
    http_get = {
      path = "/healthz"
      port = local.container_port
    }
    initial_delay_seconds = 15
    period_seconds        = 5
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 5
  }
  custom_backend_health_endpoint = "/healthz"
  project_number                             = var.project_number
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  is_public                                  = true
  kubernetes_namespace                       = var.gke_cluster_namespace
  managed_ssl_certificate_name               = var.managed_ssl_certificate_name
  number_of_replicas                         = local.number_of_replicas
  persistent_volumes                         = []
  limits_cpus                                = 2
  limits_memory                              = "1Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 1
  requests_memory                            = "1Gi"
  requests_nvidia_gpus                       = null
  service_port                               = local.service_port
  apm_enabled                                = true
  service_fqdn                               = var.domain_name_public
  private_dns_zone_name                      = var.dns_zone_name_private
  public_dns_zone_name                       = var.dns_zone_name_public
  cloudsql_databases = [
    {
      port                     = 5432
      instance_connection_name = var.database_connection_name
    }
  ]
  env = [
    {
      name  = "ENV"
      value = var.environment
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "LOGLEVEL"
      value = "INFO"
    },
    {
      name  = "POSTGRES_USER"
      value = "maindbuser"
    },
    {
      name  = "POSTGRES_HOSTNAME"
      value = "127.0.0.1" # via CloudSQL sidecar proxy
    },
    {
      name      = "POSTGRES_PASSWORD"
      value     = data.google_secret_manager_secret_version.cloudsql-maindb-maindb-password.secret_data
      sensitive = true
    },
    {
      name      = "ELASTIC_SEARCH_API_KEY"
      value     = data.google_secret_manager_secret_version.elastic-search-api-key.secret_data
      sensitive = true
    },
    {
      name      = "ELASTIC_SEARCH_CLOUD_ID"
      value     = data.google_secret_manager_secret_version.elasticsearch-cloud-id.secret_data
      sensitive = true
    },
    {
      # Always prod Amplitude (in dev, use the mirrored "amplitude-prod-api-*"
      # secrets that webapp-admin also uses). See README §"MCP analytics".
      name = "AMPLITUDE_API_KEY"
      value = var.environment == "dev" ? data.google_secret_manager_secret_version.amplitude-api-prod-key[0].secret_data : data.google_secret_manager_secret_version.amplitude-api-key.secret_data
      sensitive = true
    },
    {
      name = "AMPLITUDE_API_SECRET"
      value = var.environment == "dev" ? data.google_secret_manager_secret_version.amplitude-api-prod-secret[0].secret_data : data.google_secret_manager_secret_version.amplitude-api-secret.secret_data
      sensitive = true
    },
    {
      name  = "REDIS_HOST"
      value = var.redis_host
    },
    {
      name  = "REDIS_PORT"
      value = var.redis_port
    },
    {
      name      = "SPIFFY_USER_AUTH_TOKEN_SIGNING_SECRET"
      value     = data.google_secret_manager_secret_version.spiffy-auth-token-signing-secret.secret_data
      sensitive = true
    },
    {
      name      = "STATSIG_API_KEY"
      value     = data.google_secret_manager_secret_version.statsig_api_key.secret_data
      sensitive = true
    },
    {
      name      = "MCP_OAUTH_SIGNING_SECRET"
      value     = data.google_secret_manager_secret_version.mcp-oauth-signing-secret.secret_data
      sensitive = true
    },
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
  priority     = 2
}
