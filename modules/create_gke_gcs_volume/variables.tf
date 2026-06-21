variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "persistent_volume_name" {
  description = "Name of the persistent volume"
  type        = string
}

variable "persistent_volume_capacity" {
  description = "Capacity of the persistent volume in GiB (eg: 1Gi)"
  type        = string
}

variable "persistent_volume_claim_name" {
  description = "Specify the PersistentVolumeClaim nam"
  type        = string
}

variable "persistent_volume_claim_namespace" {
  description = "Specify the PersistentVolumeClaim namespace. (This is the same namespace as the workload namespace for the pod)"
  type        = string
}

variable "bucket_name" {
  description = "Specify your Cloud Storage bucket name. You can pass an underscore (_) to mount all the buckets that the service account is configured to have access to."
  type        = string
}

variable "persistent_volume_reclaim_policy" {
  description = "Specify the reclaim policy for the persistent volume. (eg: Retain)"
  type        = string
  default     = "Retain"
}

variable "read_only" {
  description = "Specify if the volume should be mounted as read only. (eg: true)"
  type        = bool
}

variable "mount_options" {
  description = "Mount options for the volume"
  type        = list(string)
  default = []
}
