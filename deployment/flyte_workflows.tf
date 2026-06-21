module "flyte-unionai-integration" {

  count          = contains(["prod-training", "dev-training"], var.environment) ? 1 : 0
  source         = "../modules/create_unionai_integration"
  environment    = var.environment
  project_id     = google_project.deployment-project.project_id
  project_number = google_project.deployment-project.number
}