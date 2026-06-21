resource "google_storage_bucket" "spiffy-bi-configs" {
  name                     = "spiffy-bi-configs-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "MULTI_REGIONAL"
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

resource "google_storage_bucket" "spiffy-configs" {
  name                     = "spiffy-configs-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "MULTI_REGIONAL"
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

resource "google_storage_bucket" "spiffy-deployment-artifacts" {
  name                     = "spiffy-deployment-artifacts-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "MULTI_REGIONAL"
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

resource "google_storage_bucket" "spiffy-es-snapshots" {
  name                     = "spiffy-es-snapshots-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "MULTI_REGIONAL"
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

resource "google_storage_bucket" "llm-inference-service-gcs-bucket" {
  name                     = "spiffy-llm-inference-service-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "MULTI_REGIONAL"
  project                  = var.project_id
}

resource "google_storage_bucket" "cdp-streams-data-gcs-bucket" {
  name                     = "spiffy-cdp-datastreams-${var.environment}"
  location                 = var.region_default
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "REGIONAL"
  project                  = var.project_id
}

resource "google_storage_bucket" "cdc-streams-data-gcs-bucket" {
  name                     = "spiffy-cdc-states-${var.environment}"
  location                 = var.region_default
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "REGIONAL"
  project                  = var.project_id
}

resource "google_storage_bucket" "spiffy-chat-frontend" {
  name                        = "spiffy-chat-frontend-${var.environment}"
  location                    = "US"
  force_destroy               = false
  uniform_bucket_level_access = true
  storage_class               = "MULTI_REGIONAL"
  project                     = var.project_id
  cors {
    origin = ["*"]
    method = ["GET"]
    response_header = []
  }
  timeouts {}
}

resource "google_storage_bucket" "spiffy-data-ingestion-pipeline" {
  name                        = "spiffy-data-ingestion-pipeline-${var.environment}"
  location                    = "US"
  force_destroy               = false
  uniform_bucket_level_access = true
  storage_class               = "MULTI_REGIONAL"
  project                     = var.project_id
  timeouts {}
}

resource "google_storage_bucket" "spiffy-models" {
  name                        = "spiffy-models-${var.environment}"
  location                    = "US"
  force_destroy               = false
  uniform_bucket_level_access = true
  storage_class               = "MULTI_REGIONAL"
  project                     = var.project_id
  timeouts {}
}

resource "google_storage_bucket" "spiffy-data-exchange-chord-commerce" {
  name                     = "spiffy-data-exchange-chord-commerce-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "MULTI_REGIONAL"
  project                  = var.project_id
  #   dynamic "versioning" {
  #     for_each = var.environment == "prod" ? [1] : []
  #     content {
  #         enabled = true
  #     }
  #   }
  #   dynamic "lifecycle_rule" {
  #     for_each = var.environment == "prod" ? [1] : []
  #     content {
  #       condition {
  #         age = 1
  #       }
  #       action {
  #         type = "AbortIncompleteMultipartUpload"
  #       }
  #     }
  #   }
  #   dynamic "lifecycle_rule" {
  #     for_each = var.environment == "prod" ? [] : []
  #     content {
  #       action {
  #         type = "Delete"
  #       }
  #       condition {
  #         days_since_noncurrent_time = 30
  #         send_age_if_zero = false
  #       }
  #     }
  #   }

  # delete all objects in the bucket after 30 days except those matching the specified suffix
  #   dynamic "lifecycle_rule" {
  #     for_each = var.environment == "prod" ? [1] : []
  #     content {
  #       condition {
  #         age = 30
  #         matches_suffix = ["latest.js", "production.js"]
  #       }
  #       action {
  #         type = "Delete"
  #       }
  #     }
  #   }
}

# bucket level perms
# Give cloud-build write access to some buckets
resource "google_project_iam_custom_role" "spiffy-chat-frontend-storage-bucket-write-access-custom-role" {
  count = 1 # var.environment == "prod" ? 1 : 0
  role_id     = "spiffy.spiffyChatFrontendStorageBucketReadWriteRole"
  project     = var.project_id
  title       = "Spiffy Chat Frontend Storage Bucket RW Role"
  description = "Spiffy Chat Frontend Storage Bucket RW Role"
  permissions = [
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.get",
    "storage.objects.create",
    "storage.objects.delete", # TODO: Disallow delete for files containing the keyword "prod" or "production"
    "storage.objects.list",
    "storage.objects.update" # TODO: Disallow update for files containing the keyword "prod" or "production"
  ]
}

# legacy - this can be removed once spiffy-chat-frontend-dev CDN is no longer used
data "google_iam_policy" "spiffy-chat-frontend-storage-bucket-write-access-policy-dev-env-policy" {
  count = var.environment == "dev" ? 1 : 0
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers", # required for CDN to work
    ]
  }
  binding {
    role = google_project_iam_custom_role.spiffy-chat-frontend-storage-bucket-write-access-custom-role[0].id
    members = [
      "serviceAccount:${module.spiffy-react-components-publisher[0].service_account_email}",
    ]
    condition {
      title       = "${google_storage_bucket.spiffy-chat-frontend.name} access policy"
      description = "${google_storage_bucket.spiffy-chat-frontend.name} access policy"
      expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.spiffy-chat-frontend.name}\")"
    }
  }
}

resource "google_storage_bucket_iam_policy" "spiffy-chat-frontend-storage-bucket-iam-policy-dev" {
  count       = var.environment == "dev" ? 1 : 0
  bucket      = google_storage_bucket.spiffy-chat-frontend.name
  policy_data = data.google_iam_policy.spiffy-chat-frontend-storage-bucket-write-access-policy-dev-env-policy[0].policy_data
}

data "google_iam_policy" "spiffy-chat-frontend-storage-bucket-write-access-policy-prod-env-policy" {
  count = var.environment == "prod" ? 1 : 0
  binding {
    role = "roles/storage.objectViewer"
    members = [
      "allUsers", # required for CDN to work
    ]
  }
  binding {
    role = google_project_iam_custom_role.spiffy-chat-frontend-storage-bucket-write-access-custom-role[0].id
    members = [
      "serviceAccount:${module.spiffy-react-components-publisher[0].service_account_email}",
      "serviceAccount:${module.envive-analytics-sdk-publisher[0].service_account_email}"
    ]
    condition {
      title       = "${google_storage_bucket.spiffy-chat-frontend.name} access policy"
      description = "${google_storage_bucket.spiffy-chat-frontend.name} access policy"
      expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.spiffy-chat-frontend.name}\")"
    }
  }
  binding {
    role = google_project_iam_custom_role.spiffy-chat-frontend-storage-bucket-write-access-custom-role[0].id
    members = [
      # grant access to the service account that publishes the react components from DEV. But restrict its ability to overwrite anything "prod" related
      "serviceAccount:${data.terraform_remote_state.dev.outputs.spiffy_react_components_publisher_service_account_email}",
      "serviceAccount:${data.terraform_remote_state.dev.outputs.envive_analytics_sdk_publisher_service_account_email}"
    ]
    condition {
      title      = "${google_storage_bucket.spiffy-chat-frontend.name} access policy"
      description = "${google_storage_bucket.spiffy-chat-frontend.name} access policy"
      # bucket name stars with projects/_/buckets/spiffy-chat-frontend and the object name does not contain "prod" or "production"
      expression = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.spiffy-chat-frontend.name}\") && !resource.name.endsWith(\"production.js\") && !resource.name.endsWith(\"production.js\")"
    }
  }
}

resource "google_storage_bucket_iam_policy" "spiffy-chat-frontend-storage-bucket-iam-policy-prod" {
  count       = var.environment == "prod" ? 1 : 0
  bucket      = google_storage_bucket.spiffy-chat-frontend.name
  policy_data = data.google_iam_policy.spiffy-chat-frontend-storage-bucket-write-access-policy-prod-env-policy[0].policy_data
}


resource "google_storage_bucket" "spiffy-train" {
  name                     = "spiffy-train-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "STANDARD"
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

# Used by the cypress tests to store screenshots and other testing artifacts
resource "google_storage_bucket" "spiffy-monitoring-assets" {
  name                        = "spiffy-monitoring-assets-${var.environment}"
  location                    = "us-west1"
  force_destroy               = false
  public_access_prevention    = "enforced"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  project                     = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

# Used in the cloud build trigger to store the build artifacts for spiffy-react-components
resource "google_storage_bucket" "spiffy-build-artifacts" {
  name                        = "spiffy-build-artifacts-${var.environment}"
  location                    = var.region_default
  force_destroy               = false
  public_access_prevention    = "enforced"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  project                     = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}

# Storage bucket for product catalogs ingestion receipts ...
module "spiffy-product-catalogs-receipts" {
  source               = "../modules/create_storage_bucket"
  bucket_name          = "spiffy-product-catalogs-receipts-${var.environment}"
  region               = var.region_default
  project_id           = var.project_id
  environment          = var.environment
  storage_class        = "REGIONAL"
  enable_versioning    = true
  enable_notifications = true
  life_cycle_rules = [
    # delete after 180 days
    {
      condition = {
        age = 180 # Minimum age of an object in days to satisfy this condition.
        days_since_noncurrent_time = null
        send_age_if_zero           = null
      }
      action = {
        type = "Delete"
      }
    },
    # # delete non current after 30 days
    {
      condition = {
        age = null # Minimum age of an object in days to satisfy this condition.
        days_since_noncurrent_time = 30 # Minimum age of an object in days to satisfy this condition.
        send_age_if_zero = false
      }
      action = {
        type = "Delete"
      }
    }
  ]
}

resource "google_storage_bucket" "spiffy-analytics" {
  name                     = "spiffy-analytics-${var.environment}"
  location                 = "US"
  force_destroy            = false
  public_access_prevention = "enforced"
  storage_class            = "STANDARD"
  project                  = var.project_id

  lifecycle_rule {
    condition {
      age = 1 # Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}