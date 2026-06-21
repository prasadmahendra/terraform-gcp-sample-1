locals {
  enable_resize_request = false
}

resource "google_compute_region_instance_template" "a3_dws_instance_template" {
  count                = local.enable_resize_request ? 1 : 0
  name                 = "a3-dws"
  region               = var.region_default
  description          = "This template is used to create a mig instance that is compatible with DWS resize requests."
  instance_description = "A3 GPU"
  machine_type         = "a3-ultragpu-8g"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
  }

  disk {
    source_image = "cos-cloud/cos-121-lts"
    auto_delete  = true
    boot         = true
    disk_type    = "pd-ssd"
    disk_size_gb = "1024"
    mode         = "READ_WRITE"
  }

  guest_accelerator {
    # type  = "nvidia-h100-80gb"
    type = "nvidia-h200-141gb"
    count = 8
  }

  reservation_affinity {
    type = "NO_RESERVATION"
  }

  shielded_instance_config {
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    network    = google_compute_network.vpc-deployment.id
    subnetwork = google_compute_subnetwork.deployment-subnet-app.id
  }
}

resource "google_compute_instance_group_manager" "a3_dws_instance_group_manager" {
  count                = local.enable_resize_request ? 1 : 0
  name               = "a3-dws"
  base_instance_name = "a3-dws"
  zone               = "us-central1-a"

  version {
    instance_template = google_compute_region_instance_template.a3_dws_instance_template[0].self_link
  }

  instance_lifecycle_policy {
    default_action_on_failure = "DO_NOTHING"
  }

  wait_for_instances = false

}

resource "google_compute_resize_request" "a3_resize_request" {
  count                = local.enable_resize_request ? 1 : 0
  name                   = "a3-dws"
  instance_group_manager = google_compute_instance_group_manager.a3_dws_instance_group_manager[0].name
  zone                   = "us-central1-a"
  description            = "A3 Resize request resource"
  resize_by              = 1
  requested_run_duration {
    # 1 weeks
    seconds = 604800
    nanos   = 0
  }
}