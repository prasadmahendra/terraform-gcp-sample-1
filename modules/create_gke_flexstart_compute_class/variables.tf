variable "compute_class_name" {
  description = "Name of the Compute Class"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the Compute Class"
  type        = string
}

variable "max_run_duration_seconds" {
  description = "Maximum run duration in seconds for the Compute Class"
  type        = number
}

variable "node_recycling_lead_time_seconds" {
  description = "Node recycling lead time in seconds for the Compute Class"
  type        = number
}

variable "service_account_email" {
  description = "Service account to use for the Compute Class"
  type        = string
}

variable "prioritize_spot_instances_first" {
  description = "Flag to prioritize spot instances first in the Compute Class"
  type        = bool
}

variable "local_ssd_count" {
  description = "Number of SSDs to attach to the Compute Class"
  type        = number
}

variable "boot_disk_size" {
  description = "Size of the boot disk in GB for the Compute Class"
  type        = number
}

variable "gpu_type" {
  description = "GPU accelerator type (e.g. nvidia-h100-80gb). Required for node pool auto-creation on GPU machine types so NAP provisions nodes that advertise nvidia.com/gpu. Leave null for non-GPU machine types."
  type        = string
  default     = null
}

variable "gpu_count" {
  description = "Number of GPUs to attach per node. Must be set when gpu_type is set."
  type        = number
  default     = null
}