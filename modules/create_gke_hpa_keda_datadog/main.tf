# Based on -- https://keda.sh/docs/2.17/scalers/datadog/

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "kubernetes_manifest" "datadog_metric" {
  manifest = {
    apiVersion = "datadoghq.com/v1alpha1"
    kind       = "DatadogMetric"
    metadata = {
      namespace = var.datadog_metric_namespace
      annotations = {
        "external-metrics.datadoghq.com/always-active" = "true"
      }
      name = var.datadog_metric_name
    }
    spec = {
      query = var.datadog_metric_query
    }
  }
}

# ---- KEDA ScaledObject for GCP Pub/Sub ----
resource "kubernetes_manifest" "keda_scaledobject" {
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = var.scaled_object_name
      namespace = var.namespace
    }
    spec = {
      scaleTargetRef = {
        name = var.scale_target_ref
      }
      minReplicaCount  = var.min_replica_count
      maxReplicaCount  = var.max_replica_count
      idleReplicaCount = var.idle_replica_count
      pollingInterval  = var.polling_interval_seconds
      cooldownPeriod   = var.cool_down_period_seconds
      advanced = {
        horizontalPodAutoscalerConfig = {
          behavior = {
            scaleDown = {
              stabilizationWindowSeconds = var.cool_down_period_seconds / 2
            }
          }
        }
      }
      triggers = [
        {
          type       = "datadog"
          metricType = "Value"
          authenticationRef = {
            # This name comes from modules/create_gke_config_keda --> kubernetes_manifest.keda_trigger_auth_datadog.metadata.name
            name = var.datadog_use_cluster_agent_proxy == "true" ? "keda-trigger-auth-datadog-cluster-agent" : "keda-trigger-auth-datadog-secret"
          }
          metadata = {
            query = var.datadog_metric_query
            # Whether to use the Cluster Agent as proxy to get the query values. (Values: true, false, Default: false, Optional)
            useClusterAgentProxy = var.datadog_use_cluster_agent_proxy
            # The name of the DatadogMetric object to drive the scaling events.
            datadogMetricName = var.datadog_metric_name
            # The namespace of the DatadogMetric object to drive the scaling events.
            datadogMetricNamespace = var.datadog_metric_namespace
            # Value to reach to start scaling (This value can be a float).
            queryValue = tostring(var.datadog_target_value)
            # Target value for activating the scaler. Learn more about activation here.(Default: 0, Optional, This value can be a float)
            activationQueryValue = tostring(var.datadog_activation_query_value)
            # The value of the metric to return to the HPA if Datadog doesn't find a metric value for the specified time window. If not set, an error will be returned to the HPA, which will log a warning. (Optional, This value can be a float)
            metricUnavailableValue = tostring(var.datadog_metric_unavailable_value)
            # The offset to retrieve the X to last data point. The value of last data point of some queries might be inaccurate because of the implicit rollup function, try to adjust to 1 if you encounter this issue. (Default: 0, Optional)
            lastAvailablePointOffset = tostring(var.datadog_last_available_point_offset)
            # age: The time window (in seconds) to retrieve metrics from Datadog. (Default: 90, Optional)
            age = tostring(var.datadog_age_time_window_seconds)
          }
        }
      ]
    }
  }

  depends_on = [
    #kubernetes_manifest.keda_trigger_auth_gcp
  ]
}