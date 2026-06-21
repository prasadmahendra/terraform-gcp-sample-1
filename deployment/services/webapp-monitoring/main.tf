terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}
locals {
  api_server_name = var.environment == "prod" ? "api.spiffy.ai" : "api.${var.environment}.spiffy.ai"
}

data "google_secret_manager_secret_version" "spiffy-api-key" {
  secret  = "spiffy-api-key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-monitoring-slack-webhook-url" {
  secret  = "webapp-monitoring-slack-webhook-url"
  project = var.project_id
}

data "google_secret_manager_secret_version" "webapp-monitoring-slack-webhook-url-test" {
  secret  = "webapp-monitoring-slack-webhook-url-test"
  project = var.project_id
}

module "service" {
  source           = "../../../modules/create_cloudrun_job"
  environment      = var.environment
  docker_image     = var.docker_image
  docker_image_tag = var.docker_image_tag
  name             = var.service_name
  region           = var.region
  project_id       = var.project_id
  timeout          = var.timeout
  max_retries      = 0
  docker_command = [
    "/bin/bash",
    "/opt/merchant-test-runner/scripts/run-merchant-monitoring-tests.sh",
    "cypress-merchant-tests"
  ]
  vpc_name         = var.vpc_name
  subnet_name      = var.subnet_name
  allow_vpc_access = false # No VPC access (essentially this runs in the DMZ)
  vpc_egress       = "PRIVATE_RANGES_ONLY"
  is_public        = false
  cpu_limit        = "2000m"
  memory_limit     = "8Gi"
  ports = [
    {
      name           = "http1",
      container_port = 3000
    }
  ]
  env = [
    {
      name = "MERCHANT_IDS"
      # you can use a comma separated list of merchant ids (merchant_org_short_name)
      value = "all"
    },
    {
      name  = "ASSETS_BUCKET"
      value = "spiffy-monitoring-assets-${var.environment}"
    },
    {
      name  = "GOOGLE_CLOUD_PROJECT_ID"
      value = var.project_id
    },
    {
      name = "SLACK_WEBHOOK_URL",
      value_source = {
        secret_key_ref = {
          secret  = var.service_type == "test" ? data.google_secret_manager_secret_version.webapp-monitoring-slack-webhook-url-test.secret : data.google_secret_manager_secret_version.webapp-monitoring-slack-webhook-url.secret
          version = var.service_type == "test" ? data.google_secret_manager_secret_version.webapp-monitoring-slack-webhook-url-test.version : data.google_secret_manager_secret_version.webapp-monitoring-slack-webhook-url.version
        }
      }
    },
    {
      name = "SPIFFY_API_KEY"
      value_source = {
        secret_key_ref = {
          secret  = data.google_secret_manager_secret_version.spiffy-api-key.secret
          version = data.google_secret_manager_secret_version.spiffy-api-key.version
        }
      }
    },
    {
      name  = "RUN_TYPE"
      value = "monitoring"
    },
    {
      name  = "BUNDLE_PATH"
      value = ""
    },
    {
      name  = "BUNDLE_BUCKET"
      value = "spiffy-build-artifacts-${var.environment}"
    },
    {
      name  = "BUNDLE_ENV"
      value = "prod"
    },
    {
      name  = "SPIFFY_API_URL"
      value = "https://${local.api_server_name}"
    }
  ]
  datadog_api_key       = var.datadog_api_key
  datadog_site          = var.datadog_site
  datadog_trace_enabled = var.datadog_trace_enabled
}

resource "google_cloud_run_v2_job_iam_member" "binding" {
  depends_on = [
    module.service
  ]
  count    = var.environment == "prod" ? 0 : 1 # monitoring dashboard is only on dev
  location = var.region
  project  = var.project_id
  name     = var.service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.service.service_account_email}"
}

resource "google_cloud_scheduler_job" "webapp-monitoring-job-trigger" {
  count       = var.environment == "prod" ? 0 : 1 # monitoring dashboard is only on dev
  project     = var.project_id
  region      = var.region
  name        = "${var.service_name}-trigger"
  description = "Cloud run job trigger for ${var.service_name}"
  schedule    = "0 3 * * *"
  time_zone   = "America/Los_Angeles"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${var.service_name}:run"

    oauth_token {
      service_account_email = module.service.service_account_email
    }
  }
}

resource "google_storage_bucket_iam_member" "project_iam_member_storage_user" {
  bucket = "spiffy-monitoring-assets-${var.environment}"
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.service.service_account_email}"
}

resource "google_project_iam_member" "project_iam_member_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${module.service.service_account_email}"
}

# This provides run.executions.get, run.executions.list
# https://cloud.google.com/iam/docs/roles-permissions/run#run.executions.get
resource "google_project_iam_member" "project_iam_member_cloud_run_service_agent" {
  project = var.project_id
  role    = "roles/run.viewer"
  member  = "serviceAccount:${module.service.service_account_email}"
}

# Will be needed for Temporal jobs
# resource "google_project_iam_member" "project_iam_member_run_invoker" {
#  project = var.project_id
#  role    = "roles/run.invoker"
#  member  = "serviceAccount:${module.service.service_account_email}"
# }

module "logs-anomalies-monitoring" {
  source       = "../../../modules/create_dd_logs_anomalies_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name = var.service_name
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}
