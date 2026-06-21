resource "google_compute_subnetwork" "deployment-subnet-data" {

  depends_on = [
    google_compute_network.vpc-deployment,
    data.google_compute_zones.available_zones
  ]
  name          = format("%s-data", var.environment)
  ip_cidr_range = cidrsubnet(var.cidr_block_default_region, local.max_subnet_size, 2)
  region        = var.region_default
  network       = google_compute_network.vpc-deployment-data-subnet.id

  # This field denotes the VPC flow logging options for this subnetwork. If logging is enabled, logs are exported to Cloud Logging.
  # Enable when compliance demands that we log all traffic to cloud logging! - PM
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  lifecycle {
    ignore_changes = [ip_cidr_range]
  }
}