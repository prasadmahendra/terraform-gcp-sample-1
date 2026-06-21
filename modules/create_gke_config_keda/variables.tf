variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_number" {
  description = "GCP Project Number"
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

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "cluster_name_short" {
  description = "Shorter GKE cluster name to be used as prefix on SAs for example"
  type        = string
}

variable "gke_namespaces" {
  description = "List of GKE namespaces to create"
  type        = list(string)
}

variable "gke_dns_cluster_domain" {
  description = "The DNS cluster domain, e.g. 'cluster.local'"
  type        = string
  default     = "cluster.local"
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster where the service will be deployed"
  type        = string
}

variable "datadog_site" {
  description = "Datadog site (e.g., datadoghq.com, datadoghq.eu)"
  type        = string
}

variable "datadog_cluster_agent_namespace" {
  description = "The namespace where the Datadog Cluster Agent is deployed"
  type        = string
}

variable "datadog_cluster_agent_service" {
  description = "The Cluster Agent metrics server service"
  type        = string
}

variable "datadog_cluster_agent_unsafe_ssl" {
  description = "Whether to skip SSL verification when communicating with the Datadog Cluster Agent"
  type        = string
}
