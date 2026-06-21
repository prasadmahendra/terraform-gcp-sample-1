variable "service_set_name" {
  description = ""
  type        = string
}
variable "service_gcs_bucket_name" {
  description = ""
  type        = string
}
variable "gke_cluster_name" {
  description = ""
  type        = string
}
variable "filestore_instance_name" {
  description = ""
  type        = string
}
variable "environment" {
  description = ""
  type        = string
}
variable "project_id" {
  description = ""
  type        = string
}
variable "region_codes" {
  type = map(string)
}
variable "gke_cluster_namespace" {
  description = ""
  type        = string
}
variable "persistent_volume_claim_name" {
  description = ""
  type        = string
}
variable "project_number" {
  description = ""
  type        = string
}
variable "gke_cluster_region" {
  description = ""
  type        = string
}
variable "service_account" {
  description = ""
  type        = string
}
