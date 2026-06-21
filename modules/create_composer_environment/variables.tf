variable "environment" {
  description = "Terraform env"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "service_account_name" {
  description = "Service account name"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "environment_size" {
  description = "Environment size"
  type        = string
  validation {
    condition = contains([
      "ENVIRONMENT_SIZE_SMALL", "ENVIRONMENT_SIZE_MEDIUM", "ENVIRONMENT_SIZE_LARGE"
    ], var.environment_size)
    error_message = "Must be ENVIRONMENT_SIZE_SMALL, ENVIRONMENT_SIZE_MEDIUM, and ENVIRONMENT_SIZE_LARGE"
  }
}

variable "bucket_name" {
  description = "Bucket name"
  type        = string
}