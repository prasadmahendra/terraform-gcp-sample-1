variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "gke_cluster_namespace" {
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

variable "database_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

variable "service_gcs_bucket_name" {
  description = "The name of the GCS bucket to use for the service"
  type        = string
}

variable "cloudsql_instance_name" {
  description = "The name of the CloudSQL instance that is used by the service"
  type        = string
}

variable "datadog_api_key" {
  description = "datadog api key (copy the data out of secrets manager - datadog_api_key - and place it in secrets.tfvars)"
  type        = string
}

variable "datadog_app_key" {
  description = "datadog api key (copy the data out of secrets manager - datadog_app_key - and place it in secrets.tfvars)"
  type        = string
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com, datadoghq.eu, us3.datadoghq.com, etc.)"
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

variable "gpu_accelerator_type" {
  description = "The type of GPU to use for the service"
  type        = string
}

variable "gpu_accelerator_count" {
  description = "The number of GPUs to use for the service"
  type        = number
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image to deploy"
  type        = string
}

variable "target_node_pool_name" {
  description = "Target node pool name"
  type        = string
}

variable "enable_deep_health_check" {
  description = "Enable deep health check sidecar and route probes to sidecar endpoint"
  type        = bool
  default     = false
}