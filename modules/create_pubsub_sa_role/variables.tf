variable "topic_name" {
  description = "The name of the Pub/Sub topic to access"
  type        = string
}

variable "deadletter_topic_name" {
  description = "The name of the Pub/Sub deadletter topic to access"
  type        = string
}

variable "service_account_service_name" {
  description = "The name of the service for which this service account belongs to"
  type        = string
}

variable "service_account_email" {
  description = "The email of the service account to which the role will be assigned"
  type        = string
}

variable "region" {
  description = "The region to use for the Pub/Sub service"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}