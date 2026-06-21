output "topic_name" {
  value = google_pubsub_topic.topic.name
}

output "topic_id" {
  value = google_pubsub_topic.topic.id
}

# output "topic_deadletter_name" {
#   value = var.with_dead_letter_queue ? google_pubsub_topic.topic[0].name : null
# }
#
# output "topic_deadletter_id" {
#   value =  var.with_dead_letter_queue ? google_pubsub_topic.topic[0].id : null
# }
#
