variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}
variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "bucket_name" {
  description = "The name of the storage bucket to create"
  type        = string
}

variable "life_cycle_rules" {
  description = "List of lifecycle rules for the storage bucket"
  type = list(object({
    condition = object({
      age = optional(number, null)
      days_since_noncurrent_time = optional(number, null) # Optional field for days since non-current time
      send_age_if_zero = optional(bool, null) # Optional field to send age as zero
    })
    action = object({
      type = string
    })
  }))
  default = []
}

variable "enable_notifications" {
  description = "Enable notifications for the storage bucket"
  type        = bool
  default     = false
}

variable "storage_class" {
  # STANDARD, REGIONAL, MULTI_REGIONAL
  description = "The storage class for the bucket"
  type        = string
  validation {
    condition = contains(["STANDARD", "REGIONAL", "MULTI_REGIONAL"], var.storage_class)
    error_message = "Storage class must be one of STANDARD, REGIONAL, or MULTI_REGIONAL."
  }
}

variable "enable_versioning" {
  description = "Enable versioning for the storage bucket"
  type        = bool
}
