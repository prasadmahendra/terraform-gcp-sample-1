variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image to deploy"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "project_number" {
  description = "The number of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "service_name" {
  description = "The name of the CloudRun service"
  type        = string
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "gke_cluster_namespace" {
  description = "GKE Namespace to deploy the application"
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

variable "private_dns_zone_name" {
  description = "The private DNS zone to use for the service"
  type        = string
}

variable "public_dns_zone_name" {
  description = "The public DNS zone to use for the service"
  type        = object({
    name     = string
    provider = string
  })
}

variable "vpc_name" {
  description = "The name of the VPC network (eg: vpc_dev, vpc_prod)"
  type        = string
}

variable "segment_intake_topic_id" {
  description = "The ID of the segment intake topic"
  type        = string
}

variable "redis_host" {
  description = "The host of the Redis instance"
  type        = string
}

variable "redis_port" {
  description = "The port of the Redis instance"
  type        = number
}

variable "persistence_bigquery_table_id" {
  description = "The ID of the BigQuery table to persist the data"
  type        = string
}

variable "cdp_streams_bigtable_events_table_ids" {
  description = "The ID of the Bigtable tables to give r/w access to"
  type        = list(string)
}

variable "cdp_streams_bigtable_instance_id" {
  description = "The ID of the Bigtable instance to store events"
  type        = string
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
  description = "The name of the CloudSQL instance that is used by the service"
  type        = string
}

variable "database_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

