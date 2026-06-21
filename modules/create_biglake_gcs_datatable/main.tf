# Based on docs - https://cloud.google.com/bigquery/docs/create-cloud-storage-table-biglake#create-biglake-partitioned-data

# This creates a connection in the US region named "my-connection".
# This connection is used to access the bucket.
resource "google_bigquery_connection" "bigquery_connection" {
  connection_id = "${var.table_id}-bigquery-connection"
  location      = var.region
  cloud_resource {}
}

# This grants the previous connection IAM role access to the bucket.
resource "google_project_iam_member" "project_iam_member" {
  role    = "roles/storage.objectViewer"
  project = var.project_id
  member  = "serviceAccount:${google_bigquery_connection.bigquery_connection.cloud_resource[0].service_account_id}"
}

# This makes the script wait for seven minutes before proceeding. This lets IAM
# permissions propagate.
resource "time_sleep" "default" {
  create_duration = "1m"
  depends_on      = [google_project_iam_member.project_iam_member]
}

# This creates a BigQuery table with partitioning and automatic metadata
# caching.
resource "google_bigquery_table" "bigquery_table" {
  dataset_id = var.dataset_id
  table_id   = var.table_id
  schema     = var.table_schema
  external_data_configuration {
    # This defines an external data configuration for the BigQuery table
    # that reads Parquet data from the publish directory of the default
    # Google Cloud Storage bucket.
    autodetect    = false
    source_format = var.datasource_format
    connection_id = google_bigquery_connection.bigquery_connection.name
    source_uris   = var.datasource_uris
    # This configures Hive partitioning for the BigQuery table,
    # partitioning the data by date and time.
    hive_partitioning_options {
      mode                     = "CUSTOM"
      source_uri_prefix        = "gs://${var.datasource_bucket_name}${var.datasource_bucket_path_incl_partitions}"
      require_partition_filter = true
    }
    # This enables automatic metadata refresh.
    metadata_cache_mode = "AUTOMATIC"
  }

  # This sets the maximum staleness of the metadata cache to 10 hours.
  max_staleness = "0-0 0 10:0:0"
  deletion_protection = false
  depends_on = [
    time_sleep.default
  ]
}