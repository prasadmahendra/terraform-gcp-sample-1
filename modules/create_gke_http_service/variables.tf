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

variable "config_maps" {
  description = "ConfigMaps to attach to the pod"
  type = list(object({
    name : string
    mount_path : string
    read_only : bool
    data : map(string)
    #config_map_name : string
  }))
  default = []
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
  default = []
}

variable "container_command_args" {
  description = "The entrypoint command args that is executed in the container (leave null to use the image's default entrypoint)"
  type = list(string)
  default = []
}

variable "sidecar_containers" {
  description = "Optional sidecar containers to run in the pod"
  type = list(object({
    name              = string
    image             = string
    image_pull_policy = optional(string, "Always")
    command           = optional(list(string), [])
    args              = optional(list(string), [])
    env               = optional(map(string), {})
    port              = optional(number)
    limits            = optional(map(string), {})
    requests          = optional(map(string), {})
  }))
  default = []
}

variable "liveness_probe" {
  description = "Liveness probe configuration"
  type = object({
    http_get : object({
      path : string
      port : number
      http_headers : optional(list(object({
        name : string
        value : string
      })))
    })
    initial_delay_seconds : number
    period_seconds : number
    failure_threshold : number
    success_threshold : number
    timeout_seconds : number
  })
}

variable "readiness_probe" {
  description = "Readiness probe configuration"
  type = object({
    http_get : object({
      path : string
      port : number
      http_headers : optional(list(object({
        name : string
        value : string
      })))
    })
    initial_delay_seconds : number
    period_seconds : number
    failure_threshold : number
    success_threshold : number
    timeout_seconds : number
  })
}

variable "backend_request_timeout_sec" {
  description = "LB backend-request timeout (BackendConfig spec.timeoutSec). null keeps GCP's 30s default; raise for services with legitimately long requests."
  type        = number
  default     = null
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

variable "gpu_accelerator_type_scheduling_disallowed" {
  description = "Do not permit scheduling on the GPU accelerator type VMs"
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

variable "number_of_replicas_spot_capacity" {
  description = "The number of spot cap replicas to run"
  type        = number
  default     = null # Set to null to disable spot capacity
}

variable "spot_capacity_compute_class" {
  description = "The compute class to use for the spot capacity"
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

variable "profiling_enabled" {
  description = "Whether to enable DD Profiling for the service"
  type        = bool
  default     = false
}

variable "run_as_non_root" {
  description = "Whether to run the container as a non-root user"
  type        = bool
  default     = false
}

variable "backend_security_policy_name" {
  description = "The name of the backend security policy"
  type        = string
  default     = "public-edge-compute-security-policy"
}

variable "custom_backend_health_endpoint" {
  description = "The custom backend health endpoint to use for the service"
  type        = string
  default     = null
}

variable "pod_annotations" {
  type = map(string)
  default = {}
  description = "Optional annotations to add to the pod"
}

variable "enable_local_ssd" {
  description = "Whether to enable mounting local ssd"
  type        = bool
  default     = false
}

variable "gpu_nodepool" {
  description = "Specify node pool where pod needs to be deployed"
  type        = string
  default     = null
}

variable "max_surge" {
  description = "The maximum number of pods that can be created above the desired number of pods during a rolling update. Can be a number (e.g. 1) or percentage (e.g. '50%')"
  type        = any
  default     = null
}

variable "max_unavailable" {
  description = "The maximum number of pods that can be unavailable during a rolling update. Can be a number (e.g. 1) or percentage (e.g. '50%')"
  type        = any
  default     = null
}

variable "pdb_min_available" {
  description = "Minimum number of pods that must remain available during voluntary disruptions (e.g. node drain). Set to 1 for services with 2+ replicas to avoid full downtime during node pool recreation."
  type        = number
  default     = null
}

variable "progress_deadline_seconds" {
  description = "The maximum time in seconds for a deployment to make progress before it is considered to be failed"
  type        = number
  default     = 600  # Kubernetes default is 600 seconds (10 minutes)
}

variable "subnet" {
  description = "The subnet name to use for private IP address"
  type        = string
}

variable "region" {
  description = "The region to use for the service"
  type        = string
}