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

variable "is_public" {
  description = "Whether the service is public or not"
  type        = bool
  default     = true
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

variable "subnet" {
  description = "The subnet name to use for private IP address"
  type        = string
}

variable "region" {
  description = "The region to use for the service"
  type        = string
}