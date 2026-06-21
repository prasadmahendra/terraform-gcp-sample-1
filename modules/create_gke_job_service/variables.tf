variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_number" {
  description = "GCP Project Number"
  type        = string
}

variable "kubernetes_namespace" {
  description = "The namespace to deploy the application to"
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "docker_image" {
  description = "Docker image name.r"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image to deploy"
  type        = string
}

variable "container_dns_label" {
  description = "Name of the container specified as a DNS_LABEL. Each container in a pod must have a unique name (DNS_LABEL). Cannot be updated"
  type        = string
}

variable "service_port" {
  description = "Pod load balancer port"
  type        = number
}

variable "container_port" {
  description = "Number of port to expose on the pod's IP address. This must be a valid port number, 0 < x < 65536."
  type        = number
}

variable "persistent_volumes" {
  description = "Volumes to attach to the pod"
  type = list(object({
    name : string
    mount_path : string
    read_only : bool
    persistent_volume_claim_name : string
  }))
}

variable "google_service_account_for_the_service" {
  description = "The service account to use"
  type = object({
    id : string,
    account_id : string
    email : string
  })
}

variable "container_command" {
  description = "The entrypoint command that is executed in the container (leave null to use the image's default entrypoint)"
  type = list(string)
}

variable "container_command_args" {
  description = "The entrypoint command args that is executed in the container (leave null to use the image's default entrypoint)"
  type = list(string)
}

variable "sidecar_containers" {
  description = "Optional sidecar containers to run in the job pod"
  type = list(object({
    name              = string
    image             = string
    image_pull_policy = optional(string, "IfNotPresent")
    command           = optional(list(string), [])
    args              = optional(list(string), [])
    env               = optional(map(string), {})
    port              = optional(number)
    limits            = optional(map(string), {})
    requests          = optional(map(string), {})
  }))
  default = []
}

variable "readiness_probe" {
  description = "Readiness probe configuration"
  type = object({
    grpc : optional(object({
      service_name : string
      port : number
    }))
    http_get : optional(object({
      path : string
      port : number
      http_headers : optional(list(object({
        name : string
        value : string
      })))
    }))
    initial_delay_seconds : number
    period_seconds : number
    failure_threshold : number
    success_threshold : number
    timeout_seconds : number
  })
  default = null
}

variable "liveness_probe" {
  description = "Liveness probe configuration"
  type = object({
    grpc : optional(object({
      service_name : string
      port : number
    }))
    http_get : optional(object({
      path : string
      port : number
      http_headers : optional(list(object({
        name : string
        value : string
      })))
    }))
    initial_delay_seconds : number
    period_seconds : number
    failure_threshold : number
    success_threshold : number
    timeout_seconds : number
  })
  default = null
}

variable "limits_nvidia_gpus" {
  description = "The number of Nvidia GPUs to allocate to the container (max)"
  type        = number
}

variable "limits_cpus" {
  description = "The number of CPUs to allocate to the container (max)"
  type        = number
}

variable "limits_memory" {
  description = "The amount of memory to allocate to the container (max)"
  type        = string
}

variable "requests_nvidia_gpus" {
  description = "The number of Nvidia GPUs to allocate to the container (min)"
  type        = number
}

variable "requests_cpus" {
  description = "The number of CPUs to allocate to the container (min)"
  type        = number
}

variable "requests_memory" {
  description = "The amount of memory to allocate to the container (min)"
  type        = string
}

# https://cloud.google.com/compute/docs/gpus
# https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-gpus
variable "gpu_accelerator_type" {
  description = "The type of GPU to use (see https://cloud.google.com/compute/docs/gpus)"
  type        = string
}

variable "target_node_pool_name" {
  description = "The name of the target node pool"
  type        = string
}

variable "admission_check_name" {
  description = "Name of the admission check"
  type        = string
  default     = "dws-prov"
}

variable "gpu_accelerator_type_scheduling_disallowed" {
  description = "Whether the GPU accelerator type is scheduling disallowed"
  type        = bool
  default     = false
}

variable "enable_service_directory_registry" {
  description = "Whether to enable service directory registry (service_directory_namespace_id is required if TRUE)"
  type        = bool
}

variable "service_directory_namespace_id" {
  description = "The namespace id of the service directory"
  type        = string
  default     = null
}

variable "is_public" {
  description = "Whether the service is exposed via public IP directly out of the cluster"
  type        = bool
}

variable "managed_ssl_certificate_name" {
  description = "The name of the managed SSL certificate to use for the ingress."
  type        = string
  default     = null
}

variable "service_fqdn" {
  description = "The fully qualified domain name of https endpoint for the service"
  type        = string
  default     = null
}

variable "private_dns_zone_name" {
  description = "The private DNS zone to use for the service"
  type        = string
  default     = null
}

variable "public_dns_zone_name" {
  description = "The public DNS zone to use for the service"
  type = object({
    name     = string
    provider = string
  })
  default = null
}

variable "set_shm_to_memory" {
  description = "Set the /dev/shm to the same size as the memory limit"
  type        = bool
  default     = false
}

variable "number_of_replicas" {
  description = "The number of replicas to run"
  type        = number
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

variable "env" {
  description = "The environment variables to set for the CloudRun service"
  type = list(object({
    name = string
    value = optional(string)
    value_source = optional(object({
      secret_key_ref = optional(object({
        secret = string
        version = optional(string)
      }))
    }))
  }))
  default = []
}

variable "cloudsql_databases" {
  description = "The CloudSQL databases to connect to"
  type = list(object({
    instance_connection_name = string
    port                     = number
  }))
  default = []
}

variable "apm_enabled" {
  description = "Whether to enable DD APM for the service"
  type        = bool
}

variable "run_as_non_root" {
  description = "Whether to run the container as a non-root user"
  type        = bool
  default     = false
}

variable "pod_annotations" {
  type        = map(string)
  default     = {}
  description = "Optional annotations to add to the pod"
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