resource "google_cloud_ids_endpoint" "cloud_ids_endpoint" {
  count      = 0
  name       = "${var.environment}-ids-endpoint"
  location   = "${var.region_default}-a"
  network    = google_compute_network.vpc-deployment.id
  severity   = "INFORMATIONAL"
  depends_on = [
    google_compute_network.vpc-deployment,
    google_project_service.all
  ]
}