locals {
  subscription_dead_letter_topic = "${var.subscription_name}-deadletter"
}

resource "google_pubsub_subscription" "subscription" {
  name  = var.subscription_name
  topic = var.topic_id

  message_retention_duration = var.pull_config.message_retention_duration
  retain_acked_messages      = var.pull_config.retain_acked_messages
  ack_deadline_seconds       = var.pull_config.ack_deadline_seconds

  expiration_policy {
    ttl = var.pull_config.expiration_policy_ttl
  }
  retry_policy {
    minimum_backoff = var.pull_config.retry_policy_minimum_backoff
  }
  dynamic "dead_letter_policy" {
    for_each = var.with_dead_letter_queue ? [1] : []
    content {
      dead_letter_topic = google_pubsub_topic.subscription-dead-letter-topic[0].id
      max_delivery_attempts = 5
    }
  }
  enable_message_ordering = var.pull_config.enable_message_ordering
}

resource "google_pubsub_topic" "subscription-dead-letter-topic" {
  count   = var.with_dead_letter_queue ? 1 : 0
  name    = local.subscription_dead_letter_topic
  project = var.project_id
  dynamic "message_storage_policy" {
    for_each = var.allowed_persistence_regions != null ? [1] : []
    content {
      allowed_persistence_regions = var.allowed_persistence_regions
    }
  }
  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_subscription" "subscription-dead-letter-topic-default-subscription" {
  count = var.with_dead_letter_queue ? 1 : 0
  name  = "${local.subscription_dead_letter_topic}-default-subscription"
  topic = google_pubsub_topic.subscription-dead-letter-topic[0].id
}
