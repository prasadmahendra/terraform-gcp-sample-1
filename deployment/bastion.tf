locals {
  network_name = "debug-bastion-host-${var.region_default}-network"
  pen_tester_bastion_host_enabled = var.pen_tester_bastion_host_enabled
  bastion_test_hosts_enabled = true
}

resource "google_compute_firewall" "bastion_hosts_allow_ssh" {
  count   = local.pen_tester_bastion_host_enabled && var.pen_tester_src_ip_address != null ? 1 : 0
  name    = "allow-ssh-from-specific-ip"
  network = google_compute_network.vpc-deployment.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.pen_tester_src_ip_address] # Replace with the IP address you want to allow
  target_tags   = ["ssh-access"]
}

resource "google_compute_instance" "app-pen-tester-bastion-host" {

  count        = local.pen_tester_bastion_host_enabled ? 1 : 0
  project      = google_project.deployment-project.project_id
  zone         = "${var.region_default}-a"
  name         = "app-pen-tester-bastion-host-${var.region_default}"
  machine_type = "e2-small"

  tags = ["ssh-access"] # Must match the firewall target_tags

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.vpc-deployment.name
    subnetwork = google_compute_subnetwork.deployment-subnet-app.name
    access_config {} # Required for public IP access
  }
  metadata = {
    ssh-keys = "pentester:${var.pen_tester_ssh_pub_key}"
  }
  lifecycle {
    ignore_changes = [
      # ignore changes to ssh-keys metadata
      metadata["ssh-keys"]
    ]
  }
}

resource "google_compute_instance" "app-debug-bastion-host" {

  count        = local.bastion_test_hosts_enabled ? 1 : 0
  project      = google_project.deployment-project.project_id
  zone         = "${var.region_default}-a"
  name         = "app-debug-bastion-host-${var.region_default}"
  machine_type = "e2-small"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.vpc-deployment.name
    subnetwork = google_compute_subnetwork.deployment-subnet-app.name
  }
  lifecycle {
    ignore_changes = [
      # ignore changes to ssh-keys metadata
      metadata["ssh-keys"]
    ]
  }
}

resource "google_compute_instance" "dmz-debug-bastion-host" {

  count        = local.bastion_test_hosts_enabled && var.environment == "disabled" ? 1 : 0
  project      = google_project.deployment-project.project_id
  zone         = "${var.region_default}-a"
  name         = "dmz-debug-bastion-host-${var.region_default}"
  machine_type = "e2-small"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.vpc-deployment.name
    subnetwork = google_compute_subnetwork.deployment-subnet-dmz.name
  }
  lifecycle {
    ignore_changes = [
      # ignore changes to ssh-keys metadata
      metadata["ssh-keys"]
    ]
  }
}

resource "google_compute_instance" "data-debug-bastion-host" {

  count        = local.bastion_test_hosts_enabled && var.environment == "disabled" ? 1 : 0
  project      = google_project.deployment-project.project_id
  zone         = "${var.region_default}-a"
  name         = "data-debug-bastion-host-${var.region_default}"
  machine_type = "e2-small"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = google_compute_network.vpc-deployment.name
    subnetwork = google_compute_subnetwork.deployment-subnet-data.name
  }
  lifecycle {
    ignore_changes = [
      # ignore changes to ssh-keys metadata
      metadata["ssh-keys"]
    ]
  }
}

## Create IAP SSH permissions for your test instance
#
#resource "google_project_iam_member" "project1" {
#  project = var.project_name
#  role    = "roles/iap.tunnelResourceAccessor"
#  member  = "serviceAccount:terraform-demo-aft@tcb-project-371706.iam.gserviceaccount.com"
#}
