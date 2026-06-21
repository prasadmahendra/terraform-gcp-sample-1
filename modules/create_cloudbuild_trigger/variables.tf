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

variable "org_name" {
  description = "Organization name"
  type        = string
}

variable "app_build_trigger_yaml" {
  description = "App build trigger yaml"
  type        = string
  default     = "cloudbuild.yaml"
}

variable "trigger_branch_name" {
  description = "Trigger branch name"
  type        = string
  default     = "main"
}

variable "worker_pool_name" {
  description = "Worker pool name"
  type        = string
}

variable "cloudbuild_service_account" {
  description = "Cloudbuild trigger service account id"
  type        = string
}

variable "cloudbuild_service_account_for_promotions" {
  description = "Cloudbuild trigger service account id for promotions"
  type        = string
}

variable "prod_project_id" {
  description = "GCP Project ID for PROD"
  type        = string
}

variable "pre_build_steps" {
  description = "Any prebuild steps (ex: pulling down files from a bucket)"
  type = list(object({
    name       = string
    entrypoint = string
    args       = list(string)
  }))
  default = []
}

variable "build_test_steps" {
  description = "Define the test steps"
  type = list(object({
    # if you leave image null then the build step will use the application container you are building (based on the git repo code)
    # and execute an entrypoint with args inside that docker image. If you want to run some other command (ex: gcloud or curl) against
    # the local (disk) workspace directory on the build machine (which has the container you are building cached and the git code
    # checked-out etc) then you can give a value to image
    image      = string # can be null to use the image being built
    entrypoint = string
    args       = list(string)
  }))
  default = []
}

variable "additional_packaging_steps" {
  description = "Define any pip install or publish steps"
  type = list(object({
    on_pull_requests_only = bool
    entrypoint            = string
    args                  = list(string)
    script                = string
  }))
  default = []
}

variable "additional_environment_vars_on_steps" {
  description = "Define any env vars to be made available to the steps (str=value) format"
  type        = list(string)
  default     = []
}

variable "additional_build_args_on_docker_build" {
  description = "Define any additional build args to be passed to the docker build (--build-arg env=value format)"
  type        = list(string)
  default     = []
}

variable "post_build_deployment_steps" {
  description = "Dependent gke services"
  type = list(object({
    enabled        = bool
    step_type      = string
    service_type   = string
    service_name   = string
    namespace      = string
    cluster_region = string
    cluster_name   = string
    steps = list(object({
      name       = string
      entrypoint = string
      args       = list(string)
      script     = string
    }))
  }))
  default = []
}

variable "post_pull_rebuild_config" {
  description = "Optional config to rebuild the app after pulling during promote-to-prod (e.g. to inject prod NEXT_PUBLIC_* env vars)"
  type = object({
    rebuild_script = string
    build_args     = list(string)
  })
  default = null
}

variable "main_branch_name" {
  description = "Main branch name"
  type        = string
  default     = "main"
}

variable "dockerfile_file_name" {
  description = "Dockerfile file name"
  type        = string
  default     = "Dockerfile"
}

variable "build_timeout" {
  description = "Build timeout"
  type        = string
  default     = "3600s"
}

variable "disable_sonar_checks" {
  description = "Disable sonar checks"
  type        = bool
  default     = false
}

# https://cloud.google.com/build/docs/api/reference/rest/v1/projects.builds#machinetype
variable "build_machine_type" {
  description = "Build machine type"
  type        = string
  default     = "E2_MEDIUM"
}

variable "github_deploy_key_secret_manager_version_name" {
  description = "Github deploy key secret manager version name"
  type        = string
}

variable "github_known_hosts_secret_manager_version_name" {
  description = "Github known hosts secret manager version name"
  type        = string
}

variable "linked_github_repository_id" {
  description = "Linked github repository id"
  type        = string
  default     = null
}

variable "create_linked_github_repository" {
  description = "Create linked github repository"
  type        = bool
  default     = true
}

variable "is_mono_repo" {
  description = "Is mono repo"
  type        = bool
  default     = false
}

variable "mono_repo_entrypoint_id" {
  description = "Mono repo identifier for the unique entrypoint or module name services by the build triggers"
  type        = string
  default     = null
}

variable "docker_base_image_install_pkgs_file" {
  description = "Conda env yaml file, npm package.json etc"
  type        = string
  default     = null
}

variable "docker_conditional_build_script_run_cmd" {
  description = "Conditional build script run command. This is required if incremental_docker_builder_available is true"
  type        = string
  default     = null
}

variable "incremental_docker_builder_available" {
  description = "Incremental docker builder available"
  type        = bool
  default     = false
}

variable "dockerfile_file_name_base_image" {
  description = "Dockerfile file name for base image (only applicable when incremental_docker_builder_available is true)"
  type        = string
  default     = null
}
