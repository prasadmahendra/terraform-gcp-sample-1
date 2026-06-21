output "subscription_dead_letter_topic_name" {
  value = var.with_dead_letter_queue ? google_pubsub_topic.subscription-dead-letter-topic[0].name : null
}

output "subscription_dead_letter_topic_id" {
  value = var.with_dead_letter_queue ? google_pubsub_topic.subscription-dead-letter-topic[0].name : null
}

output "subscription_name" {
  value = var.with_dead_letter_queue ? google_pubsub_subscription.subscription.name : null
}

output "subscription_id" {
  value =  var.with_dead_letter_queue ? google_pubsub_subscription.subscription.id : null
}

