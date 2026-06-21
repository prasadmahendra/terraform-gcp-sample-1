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

variable "docker_image_base" {
  description = "Docker image minus the tag"
  type = string
}

variable "docker_image_tag_from" {
  type = string
}

variable "docker_image_tag_to" {
  type = string
}

variable "cloudbuild_trigger_name_partial" {
  type = string
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
  default     = "1600s"
}

## https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
variable "build_machine_type" {
  description = "Build machine type"
  type        = string
  default     = "E2_MEDIUM"
}

variable "post_pull_rebuild_config" {
  description = "Optional config to rebuild the app inside the container after pulling (before tagging as prod). Used when build-time env vars (e.g. NEXT_PUBLIC_*) differ between dev and prod."
  type = object({
    rebuild_script = string       # Shell command to rebuild, e.g. "cd /app/admin && npm run build"
    build_args     = list(string) # Docker build args in --build-arg KEY=VALUE format
  })
  default = null
}

variable "commit_sha_suffix" {
  description = "Optional suffix appended to the commit SHA when pulling the image from the registry (e.g. '-admin' for mono-repo entrypoints). Must match the suffix used when the image was pushed during the build trigger."
  type        = string
  default     = ""
  validation {
    condition     = can(regex("^(-[A-Za-z0-9_.-]+)?$", var.commit_sha_suffix))
    error_message = "commit_sha_suffix must be empty or start with '-' and contain only Docker tag-safe characters: letters, digits, '_', '.', and '-'."
  }
}
