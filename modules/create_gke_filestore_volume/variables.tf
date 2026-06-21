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

variable "persistent_volume_reclaim_policy" {
  description = "Specify the reclaim policy for the persistent volume. (eg: Retain)"
  type        = string
  default     = "Retain"
}

variable "read_only" {
  description = "Specify if the volume should be mounted as read only. (eg: true)"
  type        = bool
}

variable "filestore_instance_ip" {
  description = "The IP address of the Filestore instance"
  type        = string
}

variable "filestore_share_name" {
  description = "The name of the Filestore share"
  type        = string
}

variable "filestore_instance_location" {
  description = "The location of the Filestore instance"
  type        = string
}

variable "filestore_instance_name" {
  description = "The name of the Filestore instance"
  type        = string
}

variable "region" {
  description = "The region where the Filestore instance is located"
  type        = string
}

variable "project_id" {
  description = "The GCP project ID where the Filestore instance is created"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC network where the Filestore instance is connected"
  type        = string
}

variable "nfs_export_ip_cidr_range" {
  description = "The CIDR range for NFS export IPs"
  type        = string
}

variable "filestore_instance_service_tier" {
  description = "The service tier for the Filestore instance. Options are STANDARD, PREMIUM, or BASIC_HDD."
  type        = string
  default     = "REGIONAL"
}
