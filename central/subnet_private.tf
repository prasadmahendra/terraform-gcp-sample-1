resource "google_compute_subnetwork" "central-subnet-private" {

  depends_on    = [google_compute_network.vpc-central]
  name          = format("%s-private", var.environment)
  ip_cidr_range = cidrsubnet(var.cidr_block, 4, 1)
  region        = var.region
  network       = google_compute_network.vpc-central.id

  lifecycle {
    ignore_changes = [ip_cidr_range]
  }

  # This field denotes the VPC flow logging options for this subnetwork. If logging is enabled, logs are exported to Cloud Logging.
  # Enable when compliance demands that we log all traffic to cloud logging! - PM
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}