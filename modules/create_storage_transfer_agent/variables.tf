variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "agent_pool_name" {
  description = "The ID of the agent pool"
  type        = string
}

variable "service_account" {
  description = "The service account to use"
  type = object({
    id : string,
    account_id : string
    email : string
  })
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster_namespace" {
  # must be created when the container cluster cluster_name is created
  description = "GKE Namespace to deploy the application"
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

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "persistent_volume_claim_name" {
  description = "The name of the persistent volume claim to use"
  type        = string
}

variable "persistent_volume_mount_path" {
  description = "The name of the persistent volume mount path on the container"
  type        = string
}

variable "persistent_volume_mount_path_read_only" {
  description = "Whether the persistent volume mount path should be read only"
  type        = bool
}

variable "number_of_replicas" {
  description = "The number of replicas to deploy"
  type        = number
}