variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image tag to deploy"
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
  description = "The region in which the service should be deployed"
  type        = string
}

variable "service_name" {
  description = "The name of the service"
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

variable "cloudsql_instance_name" {
  description = "The name of the CloudSQL instance used by the service"
  type        = string
}

variable "database_connection_name" {
  description = "Cloud SQL connection name"
  type        = string
}

variable "temporal_host" {
  description = "The host of the Temporal instance"
  type        = string
}

variable "datadog_site" {
  description = "Datadog Site (e.g. us5.datadoghq.com)"
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

variable "vpc_name" {
  description = "The name of the VPC network"
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
