# Based on -- https://keda.sh/docs/2.17/scalers/temporal/

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# ---- KEDA ScaledObject for Temporal ----
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
          type = "temporal"
          metadata = {
            namespace                = var.temporal_namespace
            taskQueue                = var.temporal_task_queue_name
            targetQueueSize          = tostring(var.queue_target_value)
            activationTargetQueueSize = tostring(var.queue_activation_query_value)
            endpoint                 = var.temporal_host
          }
          authenticationRef = {
            name = "keda-trigger-auth-temporal"
          }
        }
      ]
    }
  }
}