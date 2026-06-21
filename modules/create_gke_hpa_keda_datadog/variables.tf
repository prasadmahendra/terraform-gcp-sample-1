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

variable "idle_replica_count" {
  description = "The number of replicas to maintain when there is no activity"
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

variable "datadog_use_cluster_agent_proxy" {
  description = "Whether to use the Cluster Agent as proxy to get the query values"
  type        = string
  default     = "true"
}

variable "datadog_metric_name" {
  description = "The name of the DatadogMetric object to drive the scaling events"
  type        = string
}

variable "datadog_metric_namespace" {
  description = "The namespace of the DatadogMetric object to drive the scaling events"
  type        = string
}

variable "datadog_metric_query" {
  description = "The Datadog query to create the DatadogMetric object"
  type        = string
}

variable "datadog_target_value" {
  description = "Value to reach to start scaling"
  type        = string
}

variable "datadog_activation_query_value" {
  description = "Target value for activating the scaler"
  type        = string
}

variable "datadog_metric_unavailable_value" {
  description = "The value of the metric to return to the HPA if Datadog doesn’t find a metric value for the specified time window"
  type        = string
}

variable "datadog_last_available_point_offset" {
  description = "The offset to retrieve the X to last data point"
  type        = string
  default     = "0"
}

variable "datadog_scaling_type" {
  description = "Whether to start scaling based on the value or the average between pods"
  type        = string
  default     = "average"
}

variable "datadog_age_time_window_seconds" {
  description = "The time window (in seconds) to retrieve metrics from Datadog"
  type        = string
  default     = "90"
}


