locals {
  use_composer_v3 = true
}

resource "google_composer_environment" "composer_environment" {

  name    = var.cluster_name
  provider = google-beta  # In-place software_config.image_version upgrade is only available using google-beta provider.
  project = var.project_id
  region  = var.region
  config {
    dynamic "private_environment_config" {
      for_each = local.use_composer_v3 ? [] : [1]
      content {
        enable_private_endpoint = true
      }
    }
    dynamic "data_retention_config" {
      for_each = local.use_composer_v3 ? [] : [1]
      content {
        task_logs_retention_config {
          storage_mode = "CLOUD_LOGGING_AND_CLOUD_STORAGE"
        }
      }
    }
    resilience_mode = var.environment == "dev" ? "STANDARD_RESILIENCE" : "HIGH_RESILIENCE"
    # A highly resilient environment runs across at least two zones of a selected region
    software_config {
      image_version = local.use_composer_v3 ? "composer-3-airflow-2.9.3-build.0" : "composer-2.8.0-airflow-2.7.3"
      pypi_packages = {
#         scipy = ">=1.10.3"
#         scikit-learn = ""
#         nltk = "[machine_learning]"
      }
    }
    maintenance_window {
      end_time   = "1970-01-01T04:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=FR,SA,SU"
      start_time = "1970-01-01T00:00:00Z"
    }
    workloads_config {
      scheduler {
        cpu        = 1.0
        memory_gb  = 2
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 1.0
        memory_gb  = 2
        storage_gb = 1
      }
      worker {
        cpu        = 2.0
        memory_gb  = 2
        storage_gb = 2
        min_count  = 1
        max_count  = 3
      }
    }
    environment_size = var.environment_size
    node_config {
      network         = var.vpc_id
      subnetwork      = var.subnet_id
      tags = ["subnet-app", "service-composer-env"] # required for firewall rules
      service_account = var.service_account_name
    }
  }
  storage_config {
    bucket = var.bucket_name
  }
}
