variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "gke_cluster_namespace" {
  description = "GKE Namespace to deploy the application"
  type        = string
}

variable "project_id" {
  description = "GCP project id"
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

variable "number_of_replicas" {
  description = "Number of replicas to deploy"
  type        = number
  default     = 1
}

variable "database_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

variable "service_gcs_bucket_name" {
  description = "The name of the GCS bucket to use for the service"
  type        = string
}

variable "additional_service_gcs_bucket_names" {
  description = "The names of additional GCS buckets to use for the service"
  type        = list(string)
}

variable "cloudsql_instance_name" {
  description = "The name of the CloudSQL instance that is used by the service"
  type        = string
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
