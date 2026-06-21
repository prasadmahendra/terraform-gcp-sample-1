# Temporal worker that runs the analytics.events ETL (sanitizes the Amplitude export
# (prod EVENTS_616215, dev EVENTS_616216; resolved per env from GOOGLE_PROJECT_ID + ENV) ->
# analytics.events via a server-side MERGE). Lightweight: it submits BigQuery jobs
# and waits, so it needs no CloudSQL/Redis — only Temporal + BigQuery + Slack (engineering alerts channel).
#
# The recurring 3h schedule is NOT created here (or at worker startup); it is a
# discrete `manage_events_etl_schedule create` step after a verified one-off run.

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

locals {
  number_of_replicas = 1
  container_port     = 8080
  service_port       = 9340
}

data "google_secret_manager_secret_version" "temporal-api-key" {
  secret  = "temporal-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "slack_app_eng_alerts_webhook_url" {
  secret  = "slack_app_eng_alerts_webhook_url"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog_api_key" {
  secret  = "datadog_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog_app_key" {
  secret  = "datadog_app_key"
  project = var.project_id
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_service_account" "service_account" {
  account_id   = "${substr(var.service_name, 0, 16)}-${lower(random_string.suffix.result)}-sa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

# Read the Amplitude export (AmplitudeEvents dataset) + write analytics.events. Scoped by an IAM
# condition to just those two datasets. Relocated from the removed scheduled-query
# transfer service account.
resource "google_project_iam_custom_role" "iam_custom_role_for_service_bq_access" {
  role_id     = "spiffy.analyticsEventsEtlBqRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_name} service"
  description = "Terraform Managed - read AmplitudeEvents, write analytics for ${var.service_name}"
  permissions = [
    "bigquery.datasets.get",
    "bigquery.tables.get",
    "bigquery.tables.getData",
    "bigquery.tables.list",
    "bigquery.tables.updateData",
  ]
}

resource "google_project_iam_member" "iam_member_for_custom_role_bq_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_bq_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow analytics-events-etl big-query access"
    description = "Terraform Managed - read AmplitudeEvents, write analytics"
    expression  = <<EXPR
resource.name == "projects/${var.project_id}/datasets/AmplitudeEvents" || resource.name.startsWith("projects/${var.project_id}/datasets/AmplitudeEvents/") || resource.name == "projects/${var.project_id}/datasets/analytics" || resource.name.startsWith("projects/${var.project_id}/datasets/analytics/")
EXPR
  }
}

# jobs.create is a project-level (job resource) permission, so it cannot carry a
# dataset-scoped condition — granted unconditionally via the jobUser role.
resource "google_project_iam_member" "iam_member_for_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

module "service" {
  source             = "../../../modules/create_gke_grpc_service"
  number_of_replicas = local.number_of_replicas
  container_command  = ["python3"]
  container_command_args = [
    "-m",
    "spiffy.service.analytics.events_etl.main.adapter.inp.grpc.analytics_events_etl_broker"
  ]
  container_dns_label                        = var.service_name
  container_port                             = local.container_port
  docker_image                               = var.docker_image
  docker_image_tag                           = var.docker_image_tag
  enable_service_directory_registry          = false
  service_directory_namespace_id             = null
  environment                                = var.environment
  is_public                                  = false
  kubernetes_namespace                       = var.gke_cluster_namespace
  persistent_volumes                         = []
  project_id                                 = var.project_id
  project_number                             = var.project_number
  limits_cpus                                = 1
  limits_memory                              = "1Gi"
  limits_nvidia_gpus                         = null
  requests_cpus                              = 0.25
  requests_memory                            = "256Mi"
  requests_nvidia_gpus                       = null
  gpu_accelerator_type                       = null
  gpu_accelerator_type_scheduling_disallowed = true
  service_name                               = var.service_name
  service_port                               = local.service_port
  apm_enabled                                = false
  google_service_account_for_the_service = {
    email      = google_service_account.service_account.email
    id         = google_service_account.service_account.id
    account_id = google_service_account.service_account.account_id
  }
  cloudsql_databases = []
  # The worker hosts a health-only gRPC server (AnalyticsEventsEtl declares no RPCs);
  # these probes target its standard gRPC health endpoint on the container port.
  liveness_probe = {
    grpc = {
      service_name = "spiffy.service.analytics.events_etl.AnalyticsEventsEtl"
      port         = local.container_port
    }
    initial_delay_seconds = 30
    period_seconds        = 5
    timeout_seconds       = 3
    success_threshold     = 1
    failure_threshold     = 5
  }
  readiness_probe = {
    grpc = {
      service_name = "spiffy.service.analytics.events_etl.AnalyticsEventsEtl"
      port         = local.container_port
    }
    initial_delay_seconds = 30
    period_seconds        = 5
    timeout_seconds       = 3
    success_threshold     = 1
    failure_threshold     = 5
  }
  env = [
    {
      name  = "LOGLEVEL"
      value = "INFO"
    },
    {
      name  = "ENV"
      value = var.environment
    },
    {
      name  = "GOOGLE_PROJECT_NUMBER"
      value = var.project_number
    },
    {
      name  = "GOOGLE_PROJECT_ID"
      value = var.project_id
    },
    {
      name  = "GOOGLE_CLOUD_DEFAULT_REGION"
      value = var.region
    },
    {
      name  = "TEMPORAL_HOST"
      value = var.temporal_host
    },
    {
      name      = "TEMPORAL_API_KEY"
      value     = data.google_secret_manager_secret_version.temporal-api-key.secret_data
      sensitive = true
    },
    {
      name      = "SLACK_APP_ENG_ALERTS_WEBHOOK_URL"
      value     = data.google_secret_manager_secret_version.slack_app_eng_alerts_webhook_url.secret_data
      sensitive = true
    },
    {
      name      = "DD_API_KEY"
      value     = data.google_secret_manager_secret_version.datadog_api_key.secret_data
      sensitive = true
    },
    {
      name      = "DD_APP_KEY"
      value     = data.google_secret_manager_secret_version.datadog_app_key.secret_data
      sensitive = true
    },
    {
      name  = "DD_SITE"
      value = var.datadog_site
    },
    {
      name  = "DD_SERVICE"
      value = var.service_name
    },
  ]
  team    = var.team
  chapter = var.chapter
}
