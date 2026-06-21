# https://medium.com/google-cloud/gcp-routing-adventures-vol-1-44a57806f739
# https://cloud.google.com/shell/docs/cloud-shell-tutorials/deploystack/three-tier-app

resource "google_compute_route" "vpc-egress-route-to-public-internet" {

  name             = "vpc-${var.environment}-egress-route-to-public-internet"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc-deployment.name
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# Create Cloud Router (primary region)
# (Based on https://medium.com/google-cloud/gcp-how-to-deploy-cloud-nat-with-terraform-44745a4daaa8)
resource "google_compute_router" "cloud-router" {

  count   = local.enable_nat ? 1 : 0
  depends_on = [google_compute_network.vpc-deployment]
  project = google_project.deployment-project.project_id
  name    = "vpc-cloud-router-${var.region_default}"
  network = google_compute_network.vpc-deployment.name
  region  = var.region_default
}

# Create Cloud Router (secondary region)
# (Based on https://medium.com/google-cloud/gcp-how-to-deploy-cloud-nat-with-terraform-44745a4daaa8)
resource "google_compute_router" "cloud-router-secondary-region" {

  count   = local.enable_nat && var.region_secondary != null ? 1 : 0
  depends_on = [google_compute_network.vpc-deployment]
  project = google_project.deployment-project.project_id
  name    = "vpc-cloud-router-${var.region_secondary}"
  network = google_compute_network.vpc-deployment.name
  region  = var.region_secondary
}


# TODO: Tighten up the destination ranges by what's actually needed
# https://cloud.google.com/nat/docs/nat-rules-overview

# Create Nat Gateway for primary region
# (Based on https://medium.com/google-cloud/gcp-how-to-deploy-cloud-nat-with-terraform-44745a4daaa8)
resource "google_compute_router_nat" "nat" {

  count    = local.enable_nat ? 1 : 0
  provider = google-beta
  project  = google_project.deployment-project.project_id
  depends_on = [
    google_compute_router.cloud-router,
    google_compute_subnetwork.deployment-subnet-dmz,
    google_compute_subnetwork.deployment-subnet-app,
    google_compute_subnetwork.deployment-secondary-region-subnet-app,
    google_compute_subnetwork.deployment-subnet-data
  ]
  name                   = "nat-gateway-${var.region_default}"
  router                 = google_compute_router.cloud-router[0].name
  region                 = var.region_default
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"  # alternatively, ALL_SUBNETWORKS_ALL_IP_RANGES
  type                   = "PUBLIC"

  subnetwork {
    name = google_compute_subnetwork.deployment-subnet-dmz.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name = google_compute_subnetwork.deployment-subnet-app.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Create Nat Gateway for secondary region
resource "google_compute_router_nat" "nat_secondary_region" {

  count    = local.enable_nat && var.region_secondary != null ? 1 : 0
  provider = google-beta
  project  = google_project.deployment-project.project_id
  depends_on = [
    google_compute_router.cloud-router-secondary-region,
    google_compute_subnetwork.deployment-secondary-region-subnet-app,
  ]
  name                   = "nat-gateway-${var.region_secondary}"
  router                 = google_compute_router.cloud-router-secondary-region[0].name
  region                 = var.region_secondary
  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"  # alternatively, ALL_SUBNETWORKS_ALL_IP_RANGES
  type                   = "PUBLIC"

  subnetwork {
    name = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}