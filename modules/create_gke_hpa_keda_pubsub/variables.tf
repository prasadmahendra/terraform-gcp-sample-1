variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "project_number" {
  description = "The number of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "service_account_name" {
  description = "The name of the Kubernetes service account to use for the deployment"
  type        = string
}

variable "scale_target_ref" {
  description = "The target resource to scale, formatted as <kind>:<name>"
  type        = string
}

variable "subscription_id" {
  description = "The ID of the Pub/Sub subscription to create"
  type        = string
}

variable "namespace" {
  description = "The namespace to deploy the KEDA ScaledObject to"
  type        = string
}

variable "scaled_object_name" {
  description = "The name of the KEDA ScaledObject"
  type        = string
}

variable "min_replica_count" {
  description = "The minimum number of replicas for the deployment. Zero will cool down to zero when there is no activity"
  type        = number
}

variable "max_replica_count" {
  description = "The maximum number of replicas for the deployment"
  type        = number
}

variable "polling_interval_seconds" {
  description = "The polling interval in seconds for checking the metric"
  type        = number
  default     = 5
}

variable "cool_down_period_seconds" {
  description = "The cool down period in seconds before scaling down"
  type        = number
  default     = 60
}

variable "subscription_target_per_replica" {
  description = "The target number of messages per replica for scaling"
  type        = string
  default     = "5"
}

variable "subscription_activation_value" {
  description = "The activation value for scaling from zero"
  type        = string
  default     = "0"
}

variable "subscription_time_horizon" {
  description = "The time horizon for evaluating the subscription size"
  type        = string
  default     = "10m"
}
