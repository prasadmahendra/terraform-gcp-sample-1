variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "region" {
  description = "Region in which the BigLake database should be created"
  type        = string
}

variable "description" {
  description = "Description of the BigLake database"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "job_name" {
  description = "The name of the BigQuery job"
  type        = string
}

variable "schedule" {
  description = "The schedule for the BigQuery job"
  type        = string
}

variable "destination_table_name" {
  description = "The name of the destination table"
  type        = string
}
variable "query" {
  description = "The query to run"
  type        = string
}

variable "destination_dataset_id" {
  description = "The ID of the BigQuery dataset that this table belongs to"
  type        = string
}