data "google_compute_zones" "available_zones" {
  region  = var.region_default
  project = google_project.deployment-project.project_id
}

locals {
  #
  # Calculate the maximum subnet bitmask size based on the # of availability zones * our 3 zones (DMZ, APP, DATA)
  # This ensures room to expand into new availability zones up to max. CIDRs always map the same regardless of AZ count.
  # GCP subnets work differently than AWS subnets. Particularly, GCP subnets are not tied to a specific AZ and span
  # the entire region. This means that the subnet size must be large enough to accommodate all AZs.
  #
  # Deployment CIDR: 10.4.0.0/16
  #
  # 10.4.0.0/20	    DMZ
  # 10.4.16.0/20	APP
  # 10.4.32.0/20	DATA

  max_subnet_size = 4
  enable_nat      = true
}

resource "google_compute_network" "vpc-deployment" {
  depends_on                      = [google_project_service.all]
  project                         = google_project.deployment-project.project_id
  name                            = "vpc-${var.environment}" # TODO: rename this to vpc-env-app-subnet
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

resource "google_compute_network" "vpc-deployment-data-subnet" {
  depends_on                      = [google_project_service.all]
  project                         = google_project.deployment-project.project_id
  name                            = "vpc-${var.environment}-data-subnet"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = true
}

# This VPC is used by Skypilot
resource "google_compute_network" "vpc-skypilot" {
  count                           = var.environment == "dev" ? 1 : 0
  depends_on                      = [google_project_service.all]
  project                         = google_project.deployment-project.project_id
  name                            = "skypilot-vpc"
  auto_create_subnetworks         = true
  enable_ula_internal_ipv6        = false
  delete_default_routes_on_create = false
  routing_mode                    = "GLOBAL"
  mtu                             = 1460
}

resource "google_compute_global_address" "private_compute_global_address" {

  name          = "${var.environment}-service-networking"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  # The prefix length of the IP range. If not present, it means the address field is a single IP address.
  # This field is not applicable to addresses with addressType=INTERNAL when purpose=PRIVATE_SERVICE_CONNECT
  prefix_length = 16
  network       = google_compute_network.vpc-deployment.id
  depends_on    = [google_project_service.all]
}

resource "google_service_networking_connection" "service_networking_connection_to_vpc" {

  network                 = google_compute_network.vpc-deployment.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_compute_global_address.name]
}

resource "google_compute_global_address" "private_compute_global_address_for_data_subnet" {

  name          = "${var.environment}-data-subnet-service-networking"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  # The prefix length of the IP range. If not present, it means the address field is a single IP address.
  # This field is not applicable to addresses with addressType=INTERNAL when purpose=PRIVATE_SERVICE_CONNECT
  prefix_length = 16
  network       = google_compute_network.vpc-deployment-data-subnet.id
  depends_on    = [google_project_service.all]
}

resource "google_service_networking_connection" "service_networking_connection_to_vpc_for_data_subnet" {

  network                 = google_compute_network.vpc-deployment-data-subnet.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_compute_global_address_for_data_subnet.name]
}