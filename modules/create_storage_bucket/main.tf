locals {
  default_life_cycle_rule = {
    condition = {
      age = 1 # Minimum age of an object in days to satisfy this condition.
      send_age_if_zero           = null
      days_since_noncurrent_time = null # Optional field for days since non-current time
    }
    action = {
      type = "AbortIncompleteMultipartUpload"
    }
  }
  all_life_cycle_rules = concat([
    local.default_life_cycle_rule,
  ], var.life_cycle_rules)
}

resource "google_storage_bucket" "bucket" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = false
  public_access_prevention    = "enforced"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  project                     = var.project_id

  dynamic "versioning" {
    for_each = var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }
  dynamic "lifecycle_rule" {
    for_each = local.all_life_cycle_rules
    content {
      condition {
        age                        = lifecycle_rule.value.condition.age
        days_since_noncurrent_time = lifecycle_rule.value.condition.days_since_noncurrent_time
        send_age_if_zero           = lifecycle_rule.value.condition.send_age_if_zero
      }
      action {
        type = lifecycle_rule.value.action.type
      }
    }
  }
}

resource "google_storage_notification" "notification" {
  count          = var.enable_notifications ? 1 : 0
  bucket         = google_storage_bucket.bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.topic[0].id
  event_types = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  custom_attributes = {
    env = var.environment
  }
  depends_on = [google_pubsub_topic_iam_binding.binding]
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "binding" {
  count = var.enable_notifications ? 1 : 0
  topic = google_pubsub_topic.topic[0].id
  role  = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_pubsub_topic" "topic" {
  count = var.enable_notifications ? 1 : 0
  name  = "gcs-${var.bucket_name}"
}

resource "google_pubsub_topic" "topic-deadletter" {
  count = var.enable_notifications ? 1 : 0
  name  = "gcs-${var.bucket_name}-deadletter"
}