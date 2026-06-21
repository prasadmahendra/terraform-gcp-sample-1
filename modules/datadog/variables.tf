variable "environment" {
  description = "Environment name (dev, prod, mgmt, etc)"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "datadog_api_key" {
  description = "datadog api key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "datadog app key"
  type        = string
}

variable "datadog_endpoint" {
  description = "datadog endpoint"
  type        = string
}

variable "datadog_logs_intake_endpoint" {
  description = "datadog logs intake endpoint"
  type        = string
}