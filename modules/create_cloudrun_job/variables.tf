variable "environment" {
  description = "Spiffy environment"
  type        = string
}

variable "name" {
  description = "The name of the CloudRun service"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "docker_image" {
  description = "The Docker image to deploy to CloudRun"
  type        = string
}

variable "docker_image_tag" {
  description = "The Docker image tag to deploy to CloudRun"
  type        = string
}

variable "docker_command" {
  description = "The Docker command to run for the CloudRun service (leave null for default in Dockerfile)"
  type        = list(string)
  default     = null
}

variable "ports" {
  description = "The port to listen on"
  type        = list(object({
    # (Optional) If specified, used to specify which protocol to use.
    # Allowed values are "http1" (HTTP/1) and "h2c" (HTTP/2 end-to-end). Defaults to "http1".
    name           = string
    # (Optional) Port number the container listens on. This must be a valid port number
    # (between 1 and 65535). Defaults to "8080".
    container_port = number
  }))
}

variable "env" {
  description = "The environment variables to set for the CloudRun service"
  type        = list(object({
    name         = string
    value        = optional(string)
    value_source = optional(object({
      secret_key_ref = optional(object({
        secret  = string
        version = optional(string)
      }))
    }))
  }))
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "is_public" {
  description = "Allowing public (unauthenticated) access"
  type        = bool
}

variable "allow_vpc_access" {
  description = "Allowing private access"
  type        = bool
}

variable "vpc_egress" {
  description = "Traffic VPC egress settings. Possible values are: ALL_TRAFFIC, PRIVATE_RANGES_ONLY."
  type        = string # ALL_TRAFFIC, PRIVATE_RANGES_ONLY.
  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress)
    error_message = "Traffic VPC egress settings. Possible values are: ALL_TRAFFIC, PRIVATE_RANGES_ONLY."
  }
}

variable "max_retries" {
  description = "Max number of task retries before the job fails"
  type        = number
  default     = 3 # google cloud default
}

variable "timeout" {
  description = "The default timeout for a job"
  type        = string
  default     = "7200s"
}

variable "memory_limit" {
  description = "Memory allocated to the container"
  type        = string
  default     = "512Mi"
}

variable "cpu_limit" {
  description = "CPU allocated to the container"
  type        = string
  default     = "500m"
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = object({
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
  description = "Cloud SQL connection name used by the service"
  type        = string
  default     = null
}

variable "datastore_id" {
  description = "Datastore ID used by the service"
  type        = string
  default     = null
}

variable "pubsub_topics" {
  description = "Pub/Sub topics to give access to"
  type        = list(string)
  default     = []
}