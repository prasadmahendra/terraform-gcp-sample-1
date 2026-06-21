data "google_compute_zones" "available" {
  region = var.region
  project = google_project.deployment-central.project_id
}

resource "google_compute_network" "vpc-central" {
  depends_on                      = [google_project_service.all]
  project                         = google_project.deployment-central.project_id
  name                            = "vpc-${var.environment}"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

# Create Cloud Router
# (Based on https://medium.com/google-cloud/gcp-how-to-deploy-cloud-nat-with-terraform-44745a4daaa8)
resource "google_compute_router" "cloud-router" {

  depends_on = [google_compute_network.vpc-central]
  project    = google_project.deployment-central.project_id
  name       = "vpc-${var.environment}-cloud-router"
  network    = google_compute_network.vpc-central.name
  region     = var.region
}

# Create Nat Gateway
# (Based on https://medium.com/google-cloud/gcp-how-to-deploy-cloud-nat-with-terraform-44745a4daaa8)
resource "google_compute_router_nat" "nat" {

  depends_on                         = [google_compute_router.cloud-router]
  name                               = "nat-gateway"
  router                             = google_compute_router.cloud-router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"  # alternatively, ALL_SUBNETWORKS_ALL_IP_RANGES

  subnetwork {
    name                    = google_compute_subnetwork.central-subnet-dmz.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  subnetwork {
    name                    = google_compute_subnetwork.central-subnet-private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}