variable "environment" {
  description = "Environment"
  type        = string
}

variable "repository_connection_name" {
  description = "repository connection name"
  type        = string
}

variable "github_org_name" {
  description = "Github organization name"
  type        = string
}

variable "github_repo_name" {
  description = "Github repository name"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "dependent_cloudrun_jobs" {
  description = "Dependent cloudrun services"
  type = list(object({
    step_type      = string
    service_type   = string
    service_name   = string
    namespace      = string
    cluster_region = string
    cluster_name   = string
    steps = list(object({
      name       = string
      entrypoint = string
      args = list(string)
      script     = string
    }))
  }))
  default = []
}

variable "dependent_cloudrun_services" {
  description = "Dependent cloudrun services"
  type = list(object({
    step_type      = string
    service_type   = string
    service_name   = string
    namespace      = string
    cluster_region = string
    cluster_name   = string
    steps = list(object({
      name       = string
      entrypoint = string
      args = list(string)
      script     = string
    }))
  }))
  default = []
}

variable "docker_deployment_image" {
  type = string
}

variable "dependent_gke_services" {
  description = "Dependent gke services"
  type = list(object({
    step_type      = string
    service_type   = string
    service_name   = string
    namespace      = string
    cluster_region = string
    cluster_name   = string
    steps = list(object({
      name       = string
      entrypoint = string
      args = list(string)
      script     = string
    }))
  }))
  default = []
}

variable "dependent_custom_deploy_steps" {
  description = "Dependent custom steps"
  type = list(object({
    step_type      = string
    service_type   = string
    service_name   = string
    namespace      = string
    cluster_region = string
    cluster_name   = string
    steps = list(object({
      name       = string
      entrypoint = string
      args = list(string)
      script     = string
    }))
  }))
  default = []
}

variable "worker_pool_name" {
  description = "Worker pool name"
  type        = string
}

variable "cloudbuild_service_account" {
  description = "Cloudbuild trigger service account id"
  type        = string
}

variable "build_timeout" {
  description = "Build timeout"
  type        = string
  default     = "3200s"
}

## https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
variable "build_machine_type" {
  description = "Build machine type"
  type        = string
  default     = "E2_MEDIUM"
}

variable "docker_image_prod" {
  type = string
}