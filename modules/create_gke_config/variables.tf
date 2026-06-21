variable "environment" {
  description = "The environment tag"
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

variable "datadog_site" {
  description = "Datadog Site (eg: us5.datadoghq.com)"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API Key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog APP Key"
  type        = string
}

variable "create_namespaces" {
  description = "Create namespaces on GKE"
  type        = list(string)
  default     = []
}

variable "enable_kube_state_metrics" {
  description = "Enable kube-state-metrics"
  type        = bool
}

variable "cloud_provider" {
  description = "Cloud provider (gcp, aws, azure, crusoe)"
  type        = string
}

variable "enable_nvidia_dcgm_exporter" {
  description = "Enable Nvidia DCGM Exporter"
  type        = bool
  default     = false
}

variable "datadog_cluster_agent_namespace" {
  description = "The namespace where the Datadog Cluster Agent is deployed"
  type        = string
  default     = "datadog-ns"
}

#   #  The service name for the Cluster Agent metrics server. To find the name of the service, check the available services in the Datadog namespace and look for the *-cluster-agent-metrics* name pattern.
#  value = var.datadog_cluster_agent_metrics_service_name
variable "datadog_cluster_agent_metrics_service_name" {
  description = "The Cluster Agent metrics server service"
  type        = string
  default     = "datadog-cluster-agent-metrics"
}
