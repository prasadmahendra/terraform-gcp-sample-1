variable "environment" {
  description = "The environment tag"
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

variable "resource_flavor_name" {
  description = "Name of the resource flavor"
  type        = string
}

variable "admission_check_name" {
  description = "Name of the admission check"
  type        = string
  default     = "dws-prov"
}

variable "provisioning_config_name" {
  description = "Name of the provisioning request config"
  type        = string
  #default     = "dws-config"
}

variable "provisioning_class_name" {
  description = "Name of the provisioning class"
  type        = string
  default     = "queued-provisioning.gke.io"
}

variable "managed_resources" {
  description = "List of managed resources"
  type        = list(string)
  default     = ["nvidia.com/gpu"]
}

variable "cluster_queue_name" {
  description = "Name of the cluster queue"
  type        = string
}

variable "covered_resources" {
  description = "List of covered resources"
  type        = list(string)
  default     = ["cpu", "memory", "nvidia.com/gpu", "ephemeral-storage"]
}

variable "resources" {
  description = "List of resources with their quotas"
  type = list(object({
    name  = string
    quota = string
  }))
  default = [
    {
      name  = "cpu"
      quota = "1G"
    },
    {
      name  = "memory"
      quota = "1000000000Gi"
    },
    {
      name  = "nvidia.com/gpu"
      quota = "1G"
    },
    {
      name  = "ephemeral-storage"
      quota = "9223372036854775807"
    }
  ]
}

variable "namespace" {
  description = "Namespace for the local queue"
  type        = string
}

variable "local_queue_name" {
  description = "Name of the local queue"
  type        = string
}