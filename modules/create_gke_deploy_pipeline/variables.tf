variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "pipeline_name" {
  type = string
}

variable "region" {
  description = "The region to deploy the resources in"
  type        = string
}

variable "stage_targets" {
  type = object({
    target_name   = string
    profiles      = list(string)
    target_create = bool
    target_type   = string
    target_spec   = object({
      project_id       = string
      region           = string
      gke_cluster_name = string
      gke_cluster_sa   = string
    })
    require_approval   = bool
    exe_config_sa_name = string
    execution_config   = object({
      worker_pool = string
    })
  })
}

variable "trigger_sa_name" {
  type = string
}

variable "trigger_sa_create" {
  type = bool
}

variable "execution_output_artifact_storage_bucket" {
  type = string
}

#variable "trigger_sa_email" {
#  type = string
#}
