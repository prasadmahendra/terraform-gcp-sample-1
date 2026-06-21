locals {
  ip_ip4_cidr_range = ["35.235.240.0/20"]
  ip_ip6_cidr_range = ["2600:2d00:1:7::/64"]
}

resource "google_compute_firewall" "allow-ssh-from-iap-ipv4" {
  # count = var.environment == "dev" ? 1 : 0
  name    = "ssh-allow-ipv4"
  description = "Allow SSH from IAP to the instance (Terraform Managed)"
  network = google_compute_network.vpc-deployment.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  # Allow IAP to connect to the instance
  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = local.ip_ip4_cidr_range

  direction = "INGRESS"
  disabled  = false
  priority  = 1000 # Set to a lower priority if needed
}

resource "google_compute_firewall" "allow-ssh-from-iap-ipv6" {
  count = var.environment == "dev" ? 1 : 0
  name    = "ssh-allow-ipv6"
  description = "Allow SSH from IAP to the instance in the deployment subnet (Terraform Managed)"
  network = google_compute_network.vpc-deployment.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  # Allow IAP to connect to the instance
  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = local.ip_ip6_cidr_range

  direction = "INGRESS"
  disabled  = false
  priority  = 1000 # Set to a lower priority if needed
}


resource "google_compute_firewall" "allow-ssh-from-iap-ipv4-data-subnet" {
  count = var.environment == "dev" ? 1 : 0
  name    = "ssh-allow-data-subnet-ipv4"
  description = "Allow SSH from IAP to the instance in the data subnet (Terraform Managed)"
  network = google_compute_network.vpc-deployment-data-subnet.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  # Allow IAP to connect to the instance
  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = local.ip_ip4_cidr_range

  direction = "INGRESS"
  disabled  = false
  priority  = 1000 # Set to a lower priority if needed
}

resource "google_compute_firewall" "allow-ssh-from-iap-ipv6-data-subnet" {
  count = var.environment == "dev" ? 1 : 0
  name    = "ssh-allow-data-subnet-ipv6"
  description = "Allow SSH from IAP to the instance in the data subnet (Terraform Managed)"
  network = google_compute_network.vpc-deployment-data-subnet.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  # Allow IAP to connect to the instance
  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = local.ip_ip6_cidr_range

  direction = "INGRESS"
  disabled  = false
  priority  = 1000 # Set to a lower priority if needed
}

# SkyPilot VPC related
resource "google_compute_firewall" "allow-ssh-from-iap-ipv4-for-skypilot" {
  count = var.environment == "dev" ? 1 : 0
  name    = "ssh-allow-ipv4-for-skypilot-vpc"
  description = "Allow SSH from IAP to the instance in the Skypilot VPC (Terraform Managed)"
  network = google_compute_network.vpc-skypilot[0].name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  # Allow IAP to connect to the instance
  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = local.ip_ip4_cidr_range

  direction = "INGRESS"
  disabled  = false
  priority  = 1000 # Set to a lower priority if needed
}

resource "google_compute_firewall" "allow-ssh-from-iap-ipv6-for-skypilot" {
  count = var.environment == "dev" ? 1 : 0
  name    = "ssh-allow-ipv6-for-skypilot-vpc"
  description = "Allow SSH from IAP to the instance in the Skypilot VPC (Terraform Managed)"
  network = google_compute_network.vpc-skypilot[0].name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  # Allow IAP to connect to the instance
  # https://cloud.google.com/iap/docs/using-tcp-forwarding
  source_ranges = local.ip_ip6_cidr_range

  direction = "INGRESS"
  disabled  = false
  priority  = 1000 # Set to a lower priority if needed
}
