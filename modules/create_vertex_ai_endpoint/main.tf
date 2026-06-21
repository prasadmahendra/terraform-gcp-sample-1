resource "google_vertex_ai_endpoint" "vertex_ai_endpoint" {
  name         = var.endpoint_name
  display_name = var.endpoint_display_name
  description  = var.endpoint_description
  location     = var.region
  region       = var.region
  labels = {
    env = var.environment
  }
  network = "projects/${var.project_number}/global/networks/${var.vpc_network_name}"
  depends_on = []
}