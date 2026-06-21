terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  webapp_admin_service_port = 9910
  domain_name_public        = var.domain_name_public
  api_server_name           = var.environment == "prod" ? "api.spiffy.ai" : "api.${var.environment}.spiffy.ai"
  cdn_bucket_name           = var.environment == "prod" ? "spiffy-chat-frontend-prod" : "spiffy-chat-frontend-dev"
  spiffy_bundle_url         = var.environment == "prod" ? "https://cdn.spiffy.ai/production/universal-build/spiffy-react-components/index.js" : "https://cdn.spiffy.ai/latest/universal-build/spiffy-react-components/index.js"
  commerce_api_url          = var.environment == "prod" ? "commerce-api.spiffy.ai" : "commerce-api.${var.environment}.spiffy.ai"
}

data "google_secret_manager_secret_version" "webapp-admin-auth0-client-id" {
  secret  = "webapp-admin-auth0-client-id"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-auth0-secret" {
  secret  = "webapp-admin-auth0-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-auth0-client-secret" {
  secret  = "webapp-admin-auth0-client-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-auth0-domain" {
  secret  = "webapp-admin-auth0-domain"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-jwt-secret" {
  secret  = "webapp-admin-jwt-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-admin-next-auth-secret-key" {
  secret  = "webapp-admin-next-auth-secret-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "spiffy-api-key" {
  secret  = "spiffy-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-prod-key" {
  # TODO (SPFY-2801): use "amplitude-api-key" once Larry & Serges is fully set up
  # and generating Amplitude data in dev; this is a temporary fix
  count   = var.environment == "dev" ? 1 : 0
  secret  = "amplitude-prod-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-secret-prod-key" {
  count = var.environment == "dev" ? 1 : 0
  # TODO (SPFY-2801): use "amplitude-api-key" once Larry & Serges is fully set up
  # and generating Amplitude data in dev; this is a temporary fix
  secret  = "amplitude-prod-api-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-api-key" {
  secret  = "amplitude-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "amplitude-secret-key" {
  secret  = "amplitude-api-secret"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog-client-token" {
  secret  = "datadog_client_token_for_commerce_chat"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog-api-key" {
  secret  = var.datadog_api_key.secret
  version = var.datadog_api_key.version
  project = var.project_id
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-sa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

module "service" {
  source            = "../../../modules/create_gke_http_service"
  environment       = var.environment
  container_command = ["npm"]
  container_command_args = [
    "run", "start"
  ]
  subnet                = var.subnet
  region                = var.region
  docker_image          = var.docker_image
  docker_image_tag      = var.docker_image_tag
  service_name          = var.service_name
  project_id            = var.project_id
  project_number        = var.project_number
  service_fqdn          = var.domain_name_public
  private_dns_zone_name = var.dns_zone_name_private
  public_dns_zone_name  = var.dns_zone_name_public
  env = [
    {
      name      = "AUTH0_SECRET"
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-secret.secret_data
      sensitive = true
    },
    {
      name  = "AUTH0_BASE_URL"
      value = "https://${var.domain_name_public}"
    },
    {
      name      = "AUTH0_ISSUER_BASE_URL"
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-domain.secret_data
      sensitive = true
    },
    {
      name      = "AUTH0_CLIENT_ID"
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-client-id.secret_data
      sensitive = true
    },
    {
      name      = "AUTH0_CLIENT_SECRET"
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-client-secret.secret_data
      sensitive = true
    },
    {
      name  = "AUTH0_SCOPE"
      value = "openid profile email read:shows"
    },
    {
      name      = "REACT_APP_AUTH0_CLIENT_ID",
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-client-id.secret_data
      sensitive = true
    },
    {
      name      = "REACT_APP_AUTH0_CLIENT_SECRET",
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-client-secret.secret_data
      sensitive = true
    },
    {
      name      = "REACT_APP_AUTH0_DOMAIN",
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-domain.secret_data
      sensitive = true
    },
    {
      name  = "REACT_APP_JWT_TIMEOUT",
      value = 86400
    },
    {
      name      = "REACT_APP_JWT_SECRET",
      value     = data.google_secret_manager_secret_version.webapp-admin-jwt-secret.secret_data
      sensitive = true
    },
    {
      name  = "REACT_APP_VERSION",
      value = "v3.1.0"
    },
    {
      name  = "GENERATE_SOURCEMAP",
      value = "false"
    },
    {
      name  = "REACT_APP_GOOGLE_MAPS_API_KEY",
      value = "xxxx"
    },
    {
      name  = "NEXT_PUBLIC_ENV",
      value = var.environment
    },
    {
      name  = "NEXTAUTH_URL"
      value = "https://${var.domain_name_public}"
    },
    {
      name      = "NEXTAUTH_SECRET_KEY"
      value     = data.google_secret_manager_secret_version.webapp-admin-next-auth-secret-key.secret_data
      sensitive = true
    },
    {
      name      = "SPIFFY_API_KEY"
      value     = data.google_secret_manager_secret_version.spiffy-api-key.secret_data
      sensitive = true
    },
    {
      name  = "AMPLITUDE_PROJECT_ID"
      value = "spiffy-ai"
    },
    {
      name      = "AMPLITUDE_API_KEY"
      value     = var.environment == "dev" ? data.google_secret_manager_secret_version.amplitude-api-prod-key[0].secret_data : data.google_secret_manager_secret_version.amplitude-api-key.secret_data
      sensitive = true
    },
    {
      name      = "AMPLITUDE_SECRET_KEY"
      value     = var.environment == "dev" ? data.google_secret_manager_secret_version.amplitude-secret-prod-key[0].secret_data : data.google_secret_manager_secret_version.amplitude-secret-key.secret_data
      sensitive = true
    },
    {
      name      = "NEXT_PUBLIC_DATADOG_CLIENT_TOKEN"
      value     = data.google_secret_manager_secret_version.datadog-client-token.secret_data
      sensitive = true
    },
    {
      name  = "SPIFFY_API_URL"
      value = "https://${local.api_server_name}"
    },
    {
      name  = "SPIFFY_BUNDLE_URL"
      value = local.spiffy_bundle_url
    },
    {
      name  = "NEXTAUTH_JWT_TIMEOUT"
      value = 86400
    },
    {
      name  = "GOOGLE_CLOUD_CDN_BUCKET"
      value = local.cdn_bucket_name
    },
    {
      name  = "GOOGLE_CLOUD_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "COMMERCE_API_URL"
      value = "https://${local.commerce_api_url}"
    },
    {
      name      = "NEXT_PUBLIC_AUTH0_DOMAIN"
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-domain.secret_data
      sensitive = true
    },
    {
      name      = "NEXT_PUBLIC_AUTH0_CLIENT_ID"
      value     = data.google_secret_manager_secret_version.webapp-admin-auth0-client-id.secret_data
      sensitive = true
    },
    {
      name  = "NEXT_PUBLIC_AUTH0_AUDIENCE"
      value = "https://api.dev.envive.ai"
    },
    {
      name = "DD_API_KEY"
      value = data.google_secret_manager_secret_version.datadog-api-key.secret_data
      sensitive = true
    },
    {
      name = "DD_SITE"
      value = var.datadog_site
      sensitive = true
    },
    {
      name  = "HOSTNAME"
      value = "0.0.0.0"
    },
    {
      name  = "PORT"
      value = "3000"
    },
  ]
  is_public = true
  #datadog_api_key       = var.datadog_api_key
  #datadog_site          = var.datadog_site
  #datadog_trace_enabled = var.datadog_trace_enabled
  apm_enabled = true
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    account_id = google_service_account.service_account.account_id
    id         = google_service_account.service_account.id
  }
  container_dns_label               = var.service_name
  kubernetes_namespace              = var.cluster_namespace
  limits_cpus                       = 1
  limits_memory                     = "1Gi"
  limits_nvidia_gpus                = null
  requests_cpus                     = 1
  requests_memory                   = "1Gi"
  requests_nvidia_gpus              = null
  gpu_accelerator_type              = null
  persistent_volumes                = []
  managed_ssl_certificate_name      = var.managed_ssl_certificate_name
  number_of_replicas                = var.environment == "prod" ? 2 : 1
  container_port                    = 3000
  service_port                      = local.webapp_admin_service_port
  enable_service_directory_registry = false
  # readiness_probe                   = null
  # liveness_probe                    = null
  custom_backend_health_endpoint = "/"
  liveness_probe = {
    grpc = null
    http_get = {
      path = "/"
      port = 3000
      http_headers = [
      ]
    }
    initial_delay_seconds = 5
    period_seconds        = 5
    failure_threshold     = 3
    success_threshold     = 1
    timeout_seconds       = 10
  }
  readiness_probe = {
    grpc = null
    http_get = {
      path = "/"
      port = 3000
      http_headers = [
      ]
    }
    initial_delay_seconds = 5
    period_seconds        = 5
    failure_threshold     = 2
    success_threshold     = 1
    timeout_seconds       = 10
  }
}

# roles/storage.objectCreator: required at the bucket level
resource "google_project_iam_member" "project_iam_member_storage_creator" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow storage access"
    description = "Terraform Managed - Allow storage access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${local.cdn_bucket_name}")
EXPR
  }
}

# roles/storage.objectAdmin role for cdn_bucket_name/other/assets folder
resource "google_project_iam_member" "project_iam_member_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # TODO: Change this to the correct bucket path and tighten the condition
  condition {
    title       = "Allow storage access"
    description = "Terraform Managed - Allow storage access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${local.cdn_bucket_name}")
EXPR
  }
}

# Bucket spiffy-monitoring-assets-dev viewer role -- roles/storage.objectViewer
resource "google_project_iam_member" "project_iam_member_storage_viewer_for_monitoring_assets" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow storage access"
    description = "Terraform Managed - Allow storage access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-monitoring-assets-${var.environment}")
EXPR
  }
}

# Bucket spiffy-monitoring-assets-dev viewer role -- roles/storage.bucketViewer
resource "google_project_iam_member" "project_iam_member_storage_bucket_viewer_for_monitoring_assets" {
  project = var.project_id
  role    = "roles/storage.bucketViewer"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow storage access"
    description = "Terraform Managed - Allow storage access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/spiffy-monitoring-assets-${var.environment}")
EXPR
  }
}

resource "google_project_iam_member" "project_iam_member_datastore_access" {

  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # TODO: limit to firestore resource name "spiffy-monitoring-store"? how?
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
