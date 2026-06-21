variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "region" {
  description = "Region in which the BigQuery dataset should be created"
  type        = string
}

variable "description" {
  description = "Description of the BigQuery dataset"
  type        = string
}

variable "dataset_id" {
  description = "The ID of the BigQuery dataset"
  type        = string
}

variable "friendly_name" {
  description = "The friendly name of the BigQuery dataset"
  type        = string
}

variable "default_partition_expiration_ms" {
  description = "The default partition expiration time in milliseconds"
  type        = number
  default     = null
}

variable "default_table_expiration_ms" {
  description = "The default table expiration time in milliseconds"
  type        = number
  default     = null
}

variable "max_time_travel_hours" {
  description = "The maximum time travel in hours"
  type        = number
  default     = 96 # 4 days
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "is_case_insensitive" {
  description = "Whether the dataset is case insensitive"
  type        = bool
}

variable "storage_billing_model" {
  description = "The billing model for the dataset"
  type        = string
  # Set this flag value to LOGICAL to use logical bytes for storage billing, or to PHYSICAL
  # to use physical bytes instead. LOGICAL is the default if this flag isn't specified.
  default     = "LOGICAL"
  validation {
    condition     = var.storage_billing_model == "LOGICAL" || var.storage_billing_model == "PHYSICAL"
    error_message = "storage_billing_model must be either LOGICAL or PHYSICAL"
  }
}