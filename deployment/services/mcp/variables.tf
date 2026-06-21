variable "environment" {
  description = "Name of environment (dev, prod)"
  type        = string
}

variable "subnet" {
  description = "Subnet name to use for private IP address"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "service_name" {
  description = "Service name (must be 'mcp')"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy (the shared pymono image)"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "domain_name_public" {
  description = "Public FQDN (e.g. mcp.envive.ai or mcp.dev.envive.ai)"
  type        = string
}

variable "dns_zone_name_public" {
  description = "Public DNS zone to create the A record in"
  type = object({
    name     = string
    provider = string
  })
}

variable "dns_zone_name_private" {
  description = "Private DNS zone (for the service-private name)"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key (secret manager ref)"
  type = object({
    secret  = string
    version = string
  })
}

variable "datadog_app_key" {
  description = "Datadog APP key (secret manager ref)"
  type = object({
    secret  = string
    version = string
  })
}

variable "datadog_site" {
  description = "Datadog site"
  type        = string
}

variable "datadog_trace_enabled" {
  description = "Enable Datadog APM"
  type        = bool
  default     = true
}

variable "database_connection_name" {
  description = "Cloud SQL connection name for the IAM maindb"
  type        = string
}

variable "team" {
  description = "Owning team tag"
  type        = string
  default     = "engineering"
}

variable "chapter" {
  description = "Owning chapter tag"
  type        = string
  default     = "backend"
}

variable "redis_host" {
  description = "Redis host (for rate limiting)"
  type        = string
}

variable "redis_port" {
  description = "Redis port"
  type        = string
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_cluster_namespace" {
  description = "GKE namespace"
  type        = string
}

variable "managed_ssl_certificate_name" {
  description = "Base name for the Google-managed cert (the module appends the service name)"
  type        = string
}

variable "project_number" {
  description = "GCP project number"
  type        = string
}
