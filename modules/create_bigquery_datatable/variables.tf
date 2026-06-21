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

variable "dataset_id" {
  description = "The ID of the BigQuery dataset that this table belongs to"
  type        = string
}

variable "table_id" {
  description = "The ID of the BigQuery/BigLake datatable"
  type        = string
}

variable "table_schema" {
  description = "BigLake table schema"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "time_partitioning" {
  description = "The time partitioning configuration for the table"
  type = object({
    type          = string
    field         = string
    expiration_ms = number
  })
  default = null
}

variable "clustering" {
  description = "The clustering configuration for the table"
  type = list(string)
}

variable "deletion_protection" {
  description = "Whether the table is protected from deletion"
  type        = bool
}

variable "max_staleness" {
  description = "The maximum staleness of data that could be returned when the table (or stale MV) is queried. Staleness encoded as a string encoding of https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#interval_type"
  type        = string
  default     = null
}