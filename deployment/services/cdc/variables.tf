variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "cluster_namespace" {
  # must be created when the container cluster cluster_name is created
  description = "GKE Namespace to deploy the application"
  type        = string
}

variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "subnet" {
  description = "The subnet name to use for private IP address"
  type        = string
}

variable "region" {
  description = "The region to use for the service"
  type        = string
}

variable "project_number" {
  description = "GCP project number"
  type        = string
}

variable "service_directory_namespace_id" {
  description = "The namespace id of the service directory"
  type        = string
}

variable "managed_ssl_certificate_name" {
  description = "The name of the managed SSL certificate to use for the ingress."
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "service_fqdn" {
  description = "The fully qualified domain name of https endpoint for the service"
  type        = string
}

variable "private_dns_zone_name" {
  description = "The private DNS zone to use for the service"
  type        = string
}

variable "public_dns_zone_name" {
  description = "The public DNS zone to use for the service"
  type = object({
    name     = string
    provider = string
  })
}

variable "memory_alloc_min" {
  description = "The minimum amount of memory that the container will be allocated"
  type        = string
}

variable "cpu_alloc_min" {
  description = "The minimum amount of CPU that the container will be allocated"
  type        = number
}

variable "memory_alloc_max" {
  description = "The max amount of memory that the container will be allocated"
  type        = string
}

variable "cpu_alloc_max" {
  description = "The max amount of CPU that the container will be allocated"
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

variable "cloudsql_instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
}

variable "service_gcs_bucket_name" {
  description = "The name of the GCS bucket to use for the service"
  type        = string
}

variable "database_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

variable "data_source" {
  description = "The data source to connect to"
  type = object({
    db_name     = string
    db_schema   = string
    server_name = string
    tables_to_include = list(string)
  })
}