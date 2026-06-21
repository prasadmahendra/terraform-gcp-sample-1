module "vertex_ai_endpoint_default" {
  count                 = 0
  source                = "../modules/create_vertex_ai_endpoint"
  environment           = var.environment
  endpoint_name         = "default-endpoint"
  endpoint_display_name = "default-endpoint"
  endpoint_description  = "Default Vertex AI endpoint"
  project_id            = google_project.deployment-project.id
  project_number        = google_project.deployment-project.number
  vpc_network_id        = google_compute_network.vpc-deployment.id
  vpc_network_name      = google_compute_network.vpc-deployment.name
  region                = var.region_default
}

module "vertex_ai_endpoint_sentence_transformer_default_region" {
  count = 0
  source                = "../modules/create_vertex_ai_endpoint"
  environment           = var.environment
  endpoint_name = "sentence-transformer-${var.region_default}"
  endpoint_display_name = "sentence-transformer-${var.region_default}"
  endpoint_description  = "Sentence Transformer Vertex AI endpoint (${var.region_default})"
  project_id            = google_project.deployment-project.id
  project_number        = google_project.deployment-project.number
  vpc_network_id        = google_compute_network.vpc-deployment.id
  vpc_network_name      = google_compute_network.vpc-deployment.name
  region                = var.region_default
}

module "vertex_ai_endpoint_sentence_transformer_secondary_region" {
  count = 0
  source                = "../modules/create_vertex_ai_endpoint"
  environment           = var.environment
  endpoint_name = "sentence-transformer-${var.region_secondary}"
  endpoint_display_name = "sentence-transformer-${var.region_secondary}"
  endpoint_description  = "Sentence Transformer Vertex AI endpoint (${var.region_secondary})"
  project_id            = google_project.deployment-project.id
  project_number        = google_project.deployment-project.number
  vpc_network_id        = google_compute_network.vpc-deployment.id
  vpc_network_name      = google_compute_network.vpc-deployment.name
  region                = var.region_secondary
}