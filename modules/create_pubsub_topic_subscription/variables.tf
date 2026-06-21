variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "allowed_persistence_regions" {
  description = "The region in which the Pub/Sub topic should be created"
  type        = list(string)
}

variable "message_retention_duration" {
  description = "The duration for which messages are retained in the topic"
  type        = string
  default     = "1209600s" # 14 days
}

variable "subscription_name" {
  description = "The name of the Pub/Sub subscription to create"
  type        = string
}

variable "topic_id" {
  description = "The ID of the associated Pub/Sub topic"
  type        = string
}

variable "pull_config" {
  description = "Configuration for pull subscription"
  type = object({
    message_retention_duration   = string
    retain_acked_messages        = bool
    ack_deadline_seconds         = number
    expiration_policy_ttl        = string
    retry_policy_minimum_backoff = string
    enable_message_ordering      = bool
  })
  default = {
    message_retention_duration   = "604800s" # 7 days
    retain_acked_messages        = false
    ack_deadline_seconds         = 20
    expiration_policy_ttl        = "2678400s"
    retry_policy_minimum_backoff = "3s"
    enable_message_ordering      = false
  }
}

variable "with_dead_letter_queue" {
  description = "Flag to indicate if a dead-letter queue should be created"
  type        = bool
}
