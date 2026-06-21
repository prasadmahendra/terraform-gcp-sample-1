variable "environment" {
  description = "Environment"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_account_email" {
  description = "Service Account Email"
  type        = string
}

variable "storage_bucket_name" {
  description = "Storage Bucket Name"
  type        = string
}

variable "storage_bucket_permissions" {
  description = "Storage Bucket Permissions"
  type        = list(string)
}

variable "custom_role_id_to_create" {
  description = "Custom Role ID to Create. eg: spiffy.cicdDeploymentStorageBucketsRole"
  type        = string
}