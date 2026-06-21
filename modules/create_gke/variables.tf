variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "project_number" {
  description = "The number of the project in GCP"
  type        = string
}

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "node_locations" {
  description = "The zones for the nodes"
  type        = list(string)
  default     = []
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "subnet" {
  description = "Subnet for the cluster"
  type = object({
    name            = string
    ip_cidr_range   = string
    ipv6_cidr_range = string
  })
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "cluster_name_short" {
  description = "Shorter GKE cluster name to be used as prefix on SAs for example"
  type        = string
}

variable "remove_default_node_pool" {
  description = "Remove default node pool (can be true only when autopilot is enabled = false)"
  type        = bool
}

variable "node_pools" {
  description = "Node pools"
  type = list(object({
    name = string
    # Note - GPUs aren't available in all zones
    # https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
    # https://cloud.google.com/compute/docs/machine-resource#predefined_machine_types
    # https://cloud.google.com/compute/docs/gpus
    machine_type = string
    node_count   = number
    disk_size    = number
    autoscaling = object({
      location_policy      = string # BALANCED or ANY
      total_min_node_count = number
      total_max_node_count = number
      min_node_count       = number
      max_node_count       = number
    })
    subnet = object({
      name            = string
      ip_cidr_range   = string
      ipv6_cidr_range = string
    })
    vpc_id                = string
    preemptible           = bool
    service_account_email = string
    #  List of the type and count of accelerator cards attached to the instances
    guest_accelerator = list(object({
      # The accelerator type resource to expose to this instance.
      # (list of accelerator types here - https://cloud.google.com/compute/docs/gpus)
      # E.g.
      # nvidia-l4, nvidia-tesla-k80, nvidia-tesla-p4, nvidia-tesla-p100, nvidia-tesla-v100,
      # nvidia-tesla-t4, nvidia-tesla-a100
      type  = string
      count = number
      # Optional NVIDIA Multi-Instance GPU (MIG) partition size, e.g. "3g.40gb".
      # When set, each physical GPU is sliced into isolated instances so multiple
      # Pods can share one card (the node then advertises one nvidia.com/gpu per
      # slice). Omit (null) for whole-GPU node pools.
      # https://cloud.google.com/kubernetes-engine/docs/how-to/gpus-multi
      gpu_partition_size = optional(string)
    }))
    gvnic = object({
      enabled = bool
    })
    queued_provisioning = object({
      enabled = bool
    })
    flex_start = object({
      enabled = bool
    })
    max_run_duration = object({
      enabled  = bool
      duration = string
    })
    # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool#nested_reservation_affinity
    reservation_affinity = object({
      enabled                  = bool
      consume_reservation_type = string
      key                      = string
      values                   = list(string)
    })
    management = object({
      auto_repair  = bool
      auto_upgrade = bool
    })
    upgrade_settings = object({
      max_surge       = number
      max_unavailable = number
      strategy        = string
    })
  }))
}

variable "team" {
  description = "The team tag"
  type        = string
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#autoscaling_profile
variable "cluster_autoscaling_profile" {
  description = "The autoscaling profile for the node pool"
  type        = string
  default     = "BALANCED"
}

variable "cluster_autoscaling_enabled" {
  description = "Enable cluster autoscaling"
  type        = bool
  default     = false
}

variable "gke_hub_fleet_id" {
  description = "The ID of the GKE fleet hub"
  type        = string
}

variable "autopilot_nodes_service_account_email" {
  description = "The service account email for the autopilot nodes"
  type        = string
}

variable "enable_private_nodes" {
  description = "Enable private nodes"
  type        = bool
  default     = false
}

variable "dns_config_services_domain" {
  description = "The suffix used for all cluster service records."
  type        = string
}

variable "release_channel" {
  description = "The release channel for the cluster"
  type        = string
  default     = "STABLE"
}

variable "notification_config_topic" {
  description = "The topic for notifications"
  type        = string
}

variable "auto_provisioning_defaults_enabled" {
  description = "Enable auto provisioning defaults"
  type        = bool
}