variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image to deploy"
  type        = string
}

variable "cluster_namespace" {
  # must be created when the container cluster cluster_name is created
  description = "GKE Namespace to deploy the application"
  type        = string
}

variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "project_number" {
  description = "GCP project number"
  type        = string
}

variable "service_directory_namespace_id" {
  description = "The namespace id of the service directory"
  type        = string
}

variable "managed_ssl_certificate_name" {
  description = "The name of the managed SSL certificate to use for the ingress."
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "service_fqdn" {
  description = "The fully qualified domain name of https endpoint for the service"
  type        = string
}

variable "private_dns_zone_name" {
  description = "The private DNS zone to use for the service"
  type        = string
}

variable "public_dns_zone_name" {
  description = "The public DNS zone to use for the service"
  type = object({
    name     = string
    provider = string
  })
}

variable "model_name" {
  description = "The name of the model to use for the service"
  type        = string
}

variable "model_config" {
  description = "The configuration of the model to use for the service"
  type        = string
}

variable "gpu_accelerator_type" {
  description = "The type of GPU to use for the service"
  type        = string
}

variable "gpu_accelerator_count" {
  description = "The number of GPUs to use for the service"
  type        = number
}

variable "service_account" {
  description = "The service account to use for the LLM inference service"
  type = object({
    id : string,
    account_id : string
    email : string
  })
}

variable "attached_persistent_volume_read_only" {
  description = "Attach a persistent volume to the service is read only"
  type        = bool
}

variable "persistent_volume_claim_name_gcs_backed" {
  description = "The name of the persistent volume claim to use for the service (GCS backed)"
  type        = string
}

variable "memory_alloc_min" {
  description = "The minimum amount of memory that the container will be allocated"
  type        = string
}

variable "cpu_alloc_min" {
  description = "The minimum amount of CPU that the container will be allocated"
  type        = number
}

variable "memory_alloc_max" {
  description = "The max amount of memory that the container will be allocated"
  type        = string
}

variable "cpu_alloc_max" {
  description = "The max amount of CPU that the container will be allocated"
  type        = number
}

variable "container_command_override" {
  description = "Override the default entrypoint command to run in the container"
  type = list(string)
  default = ["python"]
}

variable "container_command_args_override" {
  description = "Override the default command arguments"
  type = list(string)
  default = []
}

variable "additional_container_command_args" {
  description = "Additional command arguments to pass to the container"
  type = list(string)
}

variable "set_shm_to_memory" {
  description = "Set the shared memory to the same size as the memory limit"
  type        = bool
}

variable "team" {
  description = "The team that owns the service"
  type        = string
  default     = "engineering"
}

variable "chapter" {
  description = "The chapter that owns the service"
  type        = string
  default     = "backend"
}

variable "number_of_replicas" {
  description = "Number of replicas to deploy"
  type        = number
  default     = 1
}

variable "number_of_replicas_spot_capacity" {
  description = "Number of replicas to deploy for spot capacity"
  type        = number
  default     = null # Set to null to disable spot capacity
}

variable "spot_capacity_compute_class" {
  description = "The compute class to use for the spot capacity"
  type        = string
  default     = null
}

variable "service_set_name" {
  description = "Service set name"
  type        = string
}

variable "service_name_suffix" {
  description = "Unique service set suffix"
  type        = string
}

variable "gpu_nodepool" {
  description = "Specify node pool where pod needs to be deployed"
  type    = string
}

variable "subnet" {
  description = "The subnet name to use for private IP address"
  type        = string
}

variable "region" {
  description = "The region to use for the service"
  type        = string
}

variable "enable_deep_health_check" {
  description = "Enable deep health check sidecar and route probes to sidecar endpoint"
  type        = bool
  default     = false
}