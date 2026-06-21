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

variable "startup_probe_port" {
  description = "Container health check probe (tcp) port"
  type        = number
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

variable "domain_name_public" {
  description = "The domain name to use for the CloudRun service"
  type        = string
}

variable "dns_zone_name_public" {
  description = "The DNS zone name (public) to use for the CloudRun service"
  type        = object({
    name     = string
    provider = string
  })
}

variable "dns_zone_name_private" {
  description = "The DNS zone name (private) to use for the CloudRun service"
  type        = string
}

variable "liveness_probe_path" {
  description = "Container health check probe (http) path"
  type        = string
}

variable "service_type" {
  description = "The type of the CloudRun service (http or grpc)"
  type        = string
  default     = "http"
}

variable "enable_grpc_transcoder" {
  description = "Enable gRPC transcoding (http -> grpc)"
  type        = bool
  default     = false
}

variable "grpc_service_name" {
  description = "The gRPC service name"
  type        = string
  default     = null
}

variable "grpc_protoc_output_base64" {
  description = "The base64 encoded protoc output for endpoints"
  type        = string
  default     = null
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

variable "cpu_idle" {
  description = "Determines whether CPU should be throttled or not outside of requests"
  type        = bool
  default     = true
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

variable "max_instance_request_concurrency" {
  description = "Maximum instance concurrency"
  type        = number
  default     = 80
}

variable "min_instance_count" {
  description = "(Optional) Minimum number of serving instances that this resource should have. Set to 1 to reduce warmup time. Defaults to 0."
  type        = number
}

variable "max_instance_count" {
  description = "(Optional) Maximum number of serving instances that this resource should have. Defaults to 2"
  type        = number
}

variable "pubsub_topics" {
  description = "Pub/Sub topics to give access to"
  type        = list(string)
  default     = []
}