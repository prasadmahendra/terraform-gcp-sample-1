resource "google_api_gateway_api" "api_gateway_api" {
  provider = google-beta
  api_id   = var.api_id
  project  = var.project_id
}

resource "google_api_gateway_api_config" "api_gw" {
  provider      = google-beta
  api           = google_api_gateway_api.api_gateway_api.api_id
  api_config_id = "${var.api_id}-config"
  project       = var.project_id

  openapi_documents {
    document {
      path     = "spec.yaml"
      contents = var.openapi_documents_contents_b64encoded
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "api_gw" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.api_gw.id
  gateway_id = var.gateway_id
  project    = var.project_id
  region     = var.region
}