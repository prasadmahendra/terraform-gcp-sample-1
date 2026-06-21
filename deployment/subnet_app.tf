locals {
  vpc_app_subnets_map = {
    "primary_region" : {
      subnet_name = google_compute_subnetwork.deployment-subnet-app.name
      subnet_ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
      subnet_ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      region = var.region_default
    }
    "secondary_region" : {
      subnet_name = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].name
      subnet_ip_cidr_range   = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].ip_cidr_range
      subnet_ipv6_cidr_range = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].ipv6_cidr_range
      region = var.region_secondary
    }
  }
}

resource "google_compute_subnetwork" "deployment-subnet-app" {

  depends_on = [
    google_compute_network.vpc-deployment,
    data.google_compute_zones.available_zones
  ]
  name          = format("%s-app", var.environment)
  ip_cidr_range = cidrsubnet(var.cidr_block_default_region, local.max_subnet_size, 1)
  region        = var.region_default
  network       = google_compute_network.vpc-deployment.id
  secondary_ip_range {
    range_name    = "subnet-app-secondary-range-1"
    ip_cidr_range = var.cidr_block_default_region_app_subnet_alt_range_1 # "192.168.0.0/17"
  }
  secondary_ip_range {
    range_name    = "subnet-app-secondary-range-2"
    ip_cidr_range = var.cidr_block_default_region_app_subnet_alt_range_2 # "192.168.128.0/17"
  }
  private_ip_google_access = true

  # This field denotes the VPC flow logging options for this subnetwork. If logging is enabled, logs are exported to Cloud Logging.
  # Enable when compliance demands that we log all traffic to cloud logging! - PM
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  lifecycle {
    ignore_changes = [
      ip_cidr_range,
      secondary_ip_range
    ]
  }
}

moved {
  from = google_compute_subnetwork.deployment-subnet-us-west1-app
  to = google_compute_subnetwork.deployment-secondary-region-subnet-app
}

resource "google_compute_subnetwork" "deployment-secondary-region-subnet-app" {

  count      = var.cidr_block_secondary_region != null ? 1 : 0
  depends_on = [
    google_compute_network.vpc-deployment,
    data.google_compute_zones.available_zones
  ]
  name          = format("%s-app-%s", var.environment, var.region_secondary)
  ip_cidr_range = cidrsubnet(var.cidr_block_secondary_region, local.max_subnet_size, 1)
  region        = var.region_secondary
  network       = google_compute_network.vpc-deployment.id
  secondary_ip_range {
    range_name    = "subnet-app-${var.region_secondary}-secondary-range-1"
    ip_cidr_range = var.cidr_block_secondary_region_app_subnet_alt_range_1 # "192.169.0.0/17"
  }
  secondary_ip_range {
    range_name    = "subnet-app-${var.region_secondary}-secondary-range-2"
    ip_cidr_range = var.cidr_block_secondary_region_app_subnet_alt_range_2 # "192.169.128.0/17"
  }
  private_ip_google_access = true

  # This field denotes the VPC flow logging options for this subnetwork. If logging is enabled, logs are exported to Cloud Logging.
  # Enable when compliance demands that we log all traffic to cloud logging! - PM
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  lifecycle {
    ignore_changes = [
      ip_cidr_range,
      secondary_ip_range
    ]
  }
}