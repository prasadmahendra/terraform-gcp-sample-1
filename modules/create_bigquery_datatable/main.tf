resource "google_bigquery_table" "bigquery_table" {
  dataset_id          = var.dataset_id
  table_id            = var.table_id
  schema = var.table_schema
  # This sets the maximum staleness of the metadata cache to 10 hours.
  deletion_protection = var.deletion_protection
  clustering          = var.clustering
  max_staleness       = var.max_staleness
  dynamic "time_partitioning" {
    for_each = var.time_partitioning != null ? [1] : []
    content {
      type          = var.time_partitioning.type
      field         = var.time_partitioning.field
      expiration_ms = var.time_partitioning.expiration_ms
    }
  }
}