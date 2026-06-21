module "artifact-registry-npm" {
  count                                        = contains(["dev", "prod"], var.environment) ? 1 : 0
  source                                       = "../modules/create_artifact_registry"
  cloudbuild_service_account_email             = data.terraform_remote_state.dev.outputs.cloudbuild_service_account_email
  environment                                  = var.environment
  gke_node_pool_service_account_email_for_dev  = data.terraform_remote_state.dev.outputs.gke_node_pool_service_account_email
  gke_node_pool_service_account_email_for_prod = data.terraform_remote_state.prod.outputs.gke_node_pool_service_account_email
  repo_name                                    = "${var.org_name}-npm"
  project_id                                   = google_project.deployment-project.project_id
  project_number                               = google_project.deployment-project.number
  region                                       = var.region_default
  registry_format                              = "npm"
}

module "artifact-registry-pypi" {
  count                                        = contains(["dev", "prod"], var.environment) ? 1 : 0
  source                                       = "../modules/create_artifact_registry"
  cloudbuild_service_account_email             = data.terraform_remote_state.dev.outputs.cloudbuild_service_account_email
  environment                                  = var.environment
  gke_node_pool_service_account_email_for_dev  = data.terraform_remote_state.dev.outputs.gke_node_pool_service_account_email
  gke_node_pool_service_account_email_for_prod = data.terraform_remote_state.prod.outputs.gke_node_pool_service_account_email
  repo_name                                    = "${var.org_name}-pypi"
  project_id                                   = google_project.deployment-project.project_id
  project_number                               = google_project.deployment-project.number
  region                                       = var.region_default
  registry_format                              = "python"
}

# dev only
module "artifact-registry-dev-docker" {
  count                                        = var.environment == "dev" ? 1 : 0
  source                                       = "../modules/create_artifact_registry"
  cloudbuild_service_account_email             = data.terraform_remote_state.dev.outputs.cloudbuild_service_account_email
  environment                                  = var.environment
  gke_node_pool_service_account_email_for_dev  = data.terraform_remote_state.dev.outputs.gke_node_pool_service_account_email
  gke_node_pool_service_account_email_for_prod = data.terraform_remote_state.prod.outputs.gke_node_pool_service_account_email
  repo_name                                    = "dev-docker"
  project_id                                   = google_project.deployment-project.project_id
  project_number                               = google_project.deployment-project.number
  region                                       = var.region_default
  registry_format                              = "docker"
}

module "artifact-registry-vertex-ai-docker-default-region" {
  count                                        = 0
  source                                       = "../modules/create_artifact_registry"
  cloudbuild_service_account_email             = data.terraform_remote_state.dev.outputs.cloudbuild_service_account_email
  environment                                  = var.environment
  gke_node_pool_service_account_email_for_dev  = data.terraform_remote_state.dev.outputs.gke_node_pool_service_account_email
  gke_node_pool_service_account_email_for_prod = data.terraform_remote_state.prod.outputs.gke_node_pool_service_account_email
  repo_name                                    = "vertex-ai"
  project_id                                   = google_project.deployment-project.project_id
  project_number                               = google_project.deployment-project.number
  region                                       = var.region_default
  registry_format                              = "docker"
}

module "artifact-registry-vertex-ai-docker-secondary-region" {
  count                                        = 0
  source                                       = "../modules/create_artifact_registry"
  cloudbuild_service_account_email             = data.terraform_remote_state.dev.outputs.cloudbuild_service_account_email
  environment                                  = var.environment
  gke_node_pool_service_account_email_for_dev  = data.terraform_remote_state.dev.outputs.gke_node_pool_service_account_email
  gke_node_pool_service_account_email_for_prod = data.terraform_remote_state.prod.outputs.gke_node_pool_service_account_email
  repo_name                                    = "vertex-ai"
  project_id                                   = google_project.deployment-project.project_id
  project_number                               = google_project.deployment-project.number
  region                                       = var.region_secondary
  registry_format                              = "docker"
}