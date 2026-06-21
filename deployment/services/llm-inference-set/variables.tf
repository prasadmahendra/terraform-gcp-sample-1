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

variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "project_number" {
  description = "GCP project number"
  type        = string
}

variable "gke_cluster_subnet" {
  description = "Subnet for the the cluster"
  type = object({
    name            = string
    ip_cidr_range   = string
    ipv6_cidr_range = string
  })
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "gke_cluster_region" {
  description = "The region of the GKE cluster"
  type        = string
}

variable "gke_cluster_namespace" {
  description = "GKE Namespace to deploy the application"
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

variable "service_set_name" {
  description = "The name of the service set. eg: llm-inference-service"
  type        = string
}

variable "inference_service_config" {
  description = "The configuration of the inference service"
  type = list(object({
    # Each pod that is unique needs a unique name in kubernetes.
    # So the pod name just becomes ""service_set_name + service_name_suffix"
    # This is an internal detail to GKE and has no functional consequences
    # It can be made a random string using terraform but made it.
    # configurable to make them more human readable in the GCP console.
    enabled                          = bool
    number_of_replicas               = number
    number_of_replicas_spot_capacity = number
    spot_capacity_compute_class      = string
    service_name_suffix              = string
    service_fqdn                     = string
    model_name                       = string
    model_config                     = string
    gpu_accelerator_type             = string
    gpu_accelerator_count            = number
    cpu_alloc_max                    = number
    cpu_alloc_min                    = number
    memory_alloc_max                 = string
    memory_alloc_min                 = string
    set_shm_to_memory                = bool
    container_command_override = list(string)
    container_command_args_override = list(string)
    additional_container_command_args = list(string)
    docker_image_override            = string
    docker_image_tag_override        = string
    enable_deep_health_check         = optional(bool, false)
    gpu_nodepool                     = optional(string, null)
  }))
  default = []
}

variable "text_generation_service_config" {
  description = "The configuration of the inference service"
  type = list(object({
    # Each pod that is unique needs a unique name in kubernetes.
    # So the pod name just becomes ""service_set_name + service_name_suffix"
    # This is an internal detail to GKE and has no functional consequences
    # It can be made a random string using terraform but made it.
    # configurable to make them more human readable in the GCP console.
    enabled                      = bool
    number_of_replicas           = number
    service_name_suffix          = string
    service_fqdn                 = string
    model_name                   = string
    model_config                 = string
    gpu_accelerator_type         = string
    gpu_accelerator_count        = number
    cpu_alloc_max                = number
    cpu_alloc_min                = number
    memory_alloc_max             = string
    memory_alloc_min             = string
    set_shm_to_memory            = bool
    container_command_override = list(string)
    container_command_args_override = list(string)
    additional_container_command_args = list(string)
    docker_image_override        = string
    docker_image_tag_override    = string
  }))
  default = []
}

variable "vpc_name" {
  description = "The name of the VPC network (eg: vpc_dev, vpc_prod)"
  type        = string
}

variable "service_gcs_bucket_name" {
  description = "The name of the GCS bucket to use for the service"
  type        = string
}

variable "region_codes" {
  description = "The region codes to use for the service"
  type        = map(string)
}
