resource "google_pubsub_topic" "topic" {
  name    = var.topic_name
  project = var.project_id
  dynamic "message_storage_policy" {
    for_each = var.allowed_persistence_regions != null ? [1] : []
    content {
      allowed_persistence_regions = var.allowed_persistence_regions
    }
  }
  message_retention_duration = var.message_retention_duration
}

# resource "google_pubsub_topic" "topic-deadletter" {
#   count   = var.with_dead_letter_queue ? 1 : 0
#   name    = "${var.topic_name}-deadletter"
#   depends_on = [google_pubsub_topic.topic]
#   project = var.project_id
#   dynamic "message_storage_policy" {
#     for_each = var.allowed_persistence_regions != null ? [1] : []
#     content {
#       allowed_persistence_regions = var.allowed_persistence_regions
#     }
#   }
#   message_retention_duration = var.message_retention_duration
# }
#
# resource "google_pubsub_subscription" "example" {
#   count = var.with_dead_letter_queue ? 1 : 0
#   name  = "${var.topic_name}-deadletter-subscription"
#   topic = google_pubsub_topic.topic-deadletter[0].id
# }