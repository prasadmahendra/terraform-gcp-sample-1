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
  default     = "604800s" # 7 days
}

variable "topic_name" {
  description = "The name of the Pub/Sub topic to create"
  type        = string
}

variable "with_dead_letter_queue" {
  description = "Flag to indicate if a dead-letter queue should be created"
  type        = bool
  default     = true
}
