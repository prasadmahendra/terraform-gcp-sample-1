locals {
  base_permissions = [
    "autoscaling.sites.writeMetrics",
    "logging.logEntries.create",
    "monitoring.dashboards.get",
    "monitoring.metricDescriptors.list",
    "monitoring.timeSeries.create",
    "monitoring.timeSeries.list",
    "serviceusage.services.use",
  ]
  sql_permissions = var.database_connection_name != null ? [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ] : []
  pubsub_permissions = var.pubsub_topics != null && length(var.pubsub_topics) > 0 ? [
    "pubsub.subscriptions.create",
    "pubsub.topics.attachSubscription",
    "pubsub.topics.publish",
    "pubsub.subscriptions.consume",
    "pubsub.snapshots.seek"
  ] : []
  enable_grpc_transcoder = var.enable_grpc_transcoder && var.service_type == "grpc" ? true : false
}

resource "google_service_account" "service_account_for_cloud_run" {
  account_id   = "${var.name}-sa"
  display_name = "Terraform Managed - SA for ${var.name}"
  project      = var.project_id
}

resource "google_project_iam_member" "service_account_for_cloud_run_secrets" {
  member  = "serviceAccount:${google_service_account.service_account_for_cloud_run.email}"
  role    = "roles/secretmanager.secretAccessor"
  project = var.project_id
}

# give datastore access to cloudrun if required
resource "google_project_iam_member" "service_account_for_cloud_run_datastore_access" {

  count   = var.datastore_id != null ? 1 : 0
  member  = "serviceAccount:${google_service_account.service_account_for_cloud_run.email}"
  role    = "roles/datastore.user"
  project = var.project_id

  condition {
    title       = "Allow datastore access"
    description = "Terraform Managed - Allow datastore access"
    expression  = "resource.name.startsWith(\"${var.datastore_id}\")"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_project_iam_custom_role" "service_account_for_cloud_run_custom_role" {
  role_id     = "spiffy.cloudRunRoleForService_${random_string.suffix.result}"
  project     = var.project_id
  title       = "CloudRun Role for ${var.name} service"
  description = "Terraform Managed - CloudRun Role for ${var.name} service"
  permissions = concat(
    local.base_permissions,
    local.sql_permissions,
    local.pubsub_permissions
  )
}

resource "google_project_iam_member" "service_account_for_cloud_run_custom_role_member" {
  project = var.project_id
  role    = google_project_iam_custom_role.service_account_for_cloud_run_custom_role.id
  member  = "serviceAccount:${google_service_account.service_account_for_cloud_run.email}"
}

resource "google_cloud_run_v2_service" "run_service" {
  name     = var.name
  location = var.region
  project  = var.project_id
  lifecycle {
    ignore_changes = [
      # Ignore changes to the service URL
      client,
      client_version,
      launch_stage
    ]
  }
  # The feature 'Direct VPC' is not supported unless 'BETA'.
  # The launch stage annotation should be specified at least as BETA.
  # Please visit https://cloud.google.com/run/docs/troubleshooting#launch-stage-validation
  # for in-depth troubleshooting documentation.
  launch_stage = "BETA"
  template {
    dynamic "volumes" {
      for_each = var.database_connection_name != null ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [var.database_connection_name]
        }
      }
    }
    max_instance_request_concurrency = var.max_instance_request_concurrency
    scaling {
      # Limit scale up to prevent any cost blow outs!
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }
    containers {
      image   = "${var.docker_image}:${var.docker_image_tag}"
      command = var.docker_command
      resources {
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = true
        limits            = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }
      dynamic "ports" {
        for_each = var.ports
        content {
          name           = ports.value.name
          container_port = ports.value.container_port
        }
      }
      dynamic "volume_mounts" {
        for_each = var.database_connection_name != null ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }
      # default env values:
      env {
        name  = "ENV"
        value = var.environment
      }
      env {
        name  = "DD_TAGS"
        value = "env:${var.environment}"
      }
      env {
        name  = "DD_SERVICE"
        value = var.name
      }
      env {
        # Datadog API key, used to send data to your Datadog account.
        name = "DD_API_KEY"
        value_source {
          secret_key_ref {
            secret  = var.datadog_api_key.secret
            version = var.datadog_api_key.version
          }
        }
      }
      env {
        # Datadog endpoint and website.
        name  = "DD_SITE"
        value = var.datadog_site
      }
      env {
        name  = "DD_TRACE_ENABLED"
        value = var.datadog_trace_enabled
      }
      env {
        name  = "DD_TRACE_PROPAGATION_STYLE"
        value = "datadog"
      }
      env {
        name  = "DD_LOGS_INJECTION"
        value = "true"
      }
      env {
        name  = "DD_LOG_LEVEL"
        value = "INFO"
      }
      env {
        # Enable Datadog's startup logs to see the agent startup logs
        # in the Cloud Run logs. Can be useful for debugging.
        name  = "DD_TRACE_STARTUP_LOGS"
        value = "false"
      }
      dynamic "env" {
        for_each = var.env
        content {
          name  = env.value.name
          value = env.value.value
          dynamic "value_source" {
            for_each = env.value.value_source == null ? [] : [env.value.value_source]
            content {
              secret_key_ref {
                secret  = value_source.value.secret_key_ref.secret
                version = value_source.value.secret_key_ref.version
              }
            }
          }
        }
      }
      startup_probe {
        initial_delay_seconds = 15
        timeout_seconds       = 2
        period_seconds        = 3
        failure_threshold     = 5
        tcp_socket {
          port = var.startup_probe_port
        }
      }
      dynamic "liveness_probe" {
        for_each = var.liveness_probe_path == null || var.liveness_probe_path == "" ? [] : [var.liveness_probe_path]
        content {
          dynamic "grpc" {
            for_each = var.service_type != "grpc" ? [] : [var.service_type]
            content {
              service = var.grpc_service_name
            }
          }
          dynamic "http_get" {
            for_each = var.service_type != "http" ? [] : [var.service_type]
            content {
              path = liveness_probe.value
            }
          }
        }
      }
    }
    dynamic "vpc_access" {
      for_each = var.allow_vpc_access ? [1] : []
      content {
        network_interfaces {
          network    = var.vpc_name
          subnetwork = var.subnet_name
          tags       = []
        }
        egress = var.vpc_egress
      }
    }
    service_account = google_service_account.service_account_for_cloud_run.email
  }
  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Allowing public (unauthenticated) access
# https://cloud.google.com/run/docs/authenticating/public
resource "google_cloud_run_service_iam_binding" "default" {
  count    = var.is_public ? 1 : 0
  location = google_cloud_run_v2_service.run_service.location
  service  = google_cloud_run_v2_service.run_service.name
  role     = "roles/run.invoker"
  members  = [
    "allUsers"
  ]
}

resource "google_cloud_run_domain_mapping" "cloud_run_domain_mapping" {
  count    = var.domain_name_public == null ? 0 : 1
  name     = var.domain_name_public
  location = google_cloud_run_v2_service.run_service.location
  metadata {
    namespace = var.project_id
  }
  spec {
    route_name = google_cloud_run_v2_service.run_service.name
  }
}

#resource "google_dns_record_set" "dns_record_set" {
#  count        = var.domain_name_public == null ? 0 : 1
#  depends_on   = [google_cloud_run_domain_mapping.cloud_run_domain_mapping]
#  name         = "${var.domain_name_public}." # must end with a '.'
#  managed_zone = var.dns_zone_name_public
#  type         = "CNAME"
#  ttl          = 300
#  rrdatas      = ["ghs.googlehosted.com."]
#}
module "dns_record_set_public" {
  count    = var.is_public ? 1 : 0
  source   = "../create_dns_recordset"
  dns_zone = var.dns_zone_name_public
  name     = "${var.domain_name_public}."
  rrdatas  = ["ghs.googlehosted.com."]
  ttl      = 300
  type     = "CNAME"
}

resource "google_dns_record_set" "dns_record_set_private" {
  count        = var.domain_name_public == null ? 0 : 1
  depends_on   = [google_cloud_run_domain_mapping.cloud_run_domain_mapping]
  name         = "${var.domain_name_public}." # must end with a '.'
  managed_zone = var.dns_zone_name_private
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["ghs.googlehosted.com."]
}

resource "google_endpoints_service" "endpoints_service_for_grpc_backend" {

  count                = var.enable_grpc_transcoder ? 1 : 0
  service_name         = "${var.name}.endpoints.project-id.cloud.goog"
  project              = var.project_id
  grpc_config          = <<-EOT
    type: google.api.Service
    config_version: 3
    name: CLOUD_RUN_HOSTNAME
    title: Cloud Endpoints + Cloud Run gRPC
    apis:
      - name: endpoints.examples.bookstore.Bookstore
    usage:
      rules:
      # ListShelves methods can be called without an API Key.
      - selector: endpoints.examples.bookstore.Bookstore.ListShelves
        allow_unregistered_calls: true
    backend:
      rules:
        - selector: "*"
          address: grpcs://BACKEND_HOST_NAME
    EOT
  protoc_output_base64 = var.grpc_protoc_output_base64
}