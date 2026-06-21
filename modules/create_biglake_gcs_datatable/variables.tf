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

variable "datasource_bucket_name" {
  description = "GCS bucket name"
  type        = string
}

variable "datasource_bucket_path_incl_partitions" {
  description = "The path to the GCS bucket where the table data is stored (example: rudderstack/{org_id:STRING}/{dt:STRING}/{hr:INT}/{min:INT}"
  type        = string
}

variable "datasource_uris" {
  description = "datasource uris example:  ['gs://some-bucket-name/rudderstack/*']. Bucket name must match datasource_bucket_name"
  type        = list(string)
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}


variable "datasource_format" {
  description = "Datasource format (CSV GOOGLE_SHEETS NEWLINE_DELIMITED_JSON AVRO ICEBERG DATASTORE_BACKUP PARQUET ORC BIGTABLE])"
  type = string
  # CSV GOOGLE_SHEETS NEWLINE_DELIMITED_JSON AVRO ICEBERG DATASTORE_BACKUP PARQUET ORC BIGTABLE
  validation {
    condition = contains([
      "CSV",
      "GOOGLE_SHEETS",
      "NEWLINE_DELIMITED_JSON",
      "AVRO",
      "ICEBERG",
      "DATASTORE_BACKUP",
      "PARQUET",
      "BIGTABLE"
    ], var.datasource_format)
    error_message = "datasource_format must be CSV GOOGLE_SHEETS NEWLINE_DELIMITED_JSON AVRO ICEBERG DATASTORE_BACKUP PARQUET ORC BIGTABLE"
  }

}