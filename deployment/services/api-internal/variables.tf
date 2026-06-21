variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "subnet" {
  description = "The subnet name to use for private IP address"
  type        = string
}

variable "region" {
  description = "The region to use for the service"
  type        = string
}

variable "project_id" {
  description = "gc project id"
  type        = string
}

variable "service_name" {
  description = "The name of the CloudRun service"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "domain_name_public" {
  description = "Domain name for the service e.g: feeltheagi.dev.spiffy.ai"
  type        = string
}

variable "dns_zone_name_public" {
  description = "The DNS zone name (public) to use for the CloudRun service"
  type = object({
    name     = string
    provider = string
  })
}

variable "dns_zone_name_private" {
  description = "The DNS zone name (private) to use for the CloudRun service"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type = object({
    secret  = string
    version = string
  })
}

variable "datadog_app_key" {
  description = "Datadog APP key"
  type = object({
    secret  = string
    version = string
  })
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com, datadoghq.eu, us3.datadoghq.com, etc.)"
  type        = string
}

variable "datadog_trace_enabled" {
  description = "Enable Datadog APM"
  type        = bool
}

variable "database_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
  default     = null
}

variable "datastore_id" {
  description = "Datastore (NoSQL) ID"
  type        = string
  default     = null
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

variable "redis_host" {
  description = "Redis host"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = string
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "gke_cluster_namespace" {
  description = "GKE Namespace to deploy the application"
  type        = string
}

variable "managed_ssl_certificate_name" {
  description = "The name of the managed SSL certificate to use for the ingress."
  type        = string
}

variable "project_number" {
  description = "GCP project"
  type        = string
}

variable "cloudsql_instance_name" {
  description = "The name of the CloudSQL instance that is used by the service"
  type        = string
}

variable "temporal_host" {
  description = "The host of the Temporal instance"
  type        = string
}

variable "dev_api_internal_service_account_email" {
  description = "The service account email for the api-internal service in dev environment"
  type        = string
  # data.terraform_remote_state.dev.outputs.api_internal_service_account_email
}
