resource "google_service_directory_service" "service_directory_service" {

  provider   = google-beta
  service_id = var.service_name
  namespace  = var.service_directory_namespace_id
}

resource "google_service_directory_endpoint" "service_directory_endpoint" {

  provider    = google-beta
  endpoint_id = "${var.service_name}-endpoint"
  service     = google_service_directory_service.service_directory_service.id

  metadata = {
    stage  = var.environment
    region = var.region
  }

  network = "projects/${var.project_number}/locations/global/networks/${var.vpc_name}"
  address = var.ip_address
  port    = var.port
}

resource "google_network_services_service_binding" "network_services_service_binding" {

  provider = google-beta
  project  = var.project_id
  name     = "${var.service_name}-${var.region}-svc-disco-binding"
  labels   = {
    env = var.environment
  }
  description = "Service binding that references a Service Directory for ${var.service_name} (${var.region})"
  service     = google_service_directory_service.service_directory_service.id
}