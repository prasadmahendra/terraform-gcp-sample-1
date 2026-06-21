variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "project_number" {
  description = "The number of the project in GCP"
  type        = string
}

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "pipeline_name" {
  description = "CD pipeline name"
  type        = string
}

variable "pipeline_description" {
  description = "CD pipeline description"
  type        = string
}

variable "stages" {
  description = "CD pipeline stages"
  type        = list(object({
    target_id = string
    profiles  = list(string)
  }))
}