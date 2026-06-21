variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "project_number" {
  description = "The number of the project in GCP"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

variable "repo_name" {
  description = "The name of repository"
  type        = string
}

variable "registry_format" {
  description = "The format of the registry (docker, npm etc)"
  type        = string
}

variable "cloudbuild_service_account_email" {
  description = "The email of the cloudbuild service account"
  type        = string
}

variable "gke_node_pool_service_account_email_for_prod" {
  description = "The email of the service account for the node pool in the production cluster"
  type        = string
}

variable "gke_node_pool_service_account_email_for_dev" {
  description = "The email of the service account for the node pool in the dev cluster"
  type        = string
}
