output "datadog_cluster_agent_namespace" {
  value = var.datadog_cluster_agent_namespace
}

output "datadog_cluster_agent_metrics_service_name" {
  #  The service name for the Cluster Agent metrics server. To find the name of the service, check the available services in the Datadog namespace and look for the *-cluster-agent-metrics* name pattern.
  value = var.datadog_cluster_agent_metrics_service_name
}

output "datadog_cluster_agent_service" {
  value = "datadog-agent-cluster-agent-metrics-api"
}