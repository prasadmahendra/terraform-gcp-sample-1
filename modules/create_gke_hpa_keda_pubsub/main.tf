# Based on -- https://cloud.google.com/kubernetes-engine/docs/tutorials/scale-to-zero-using-keda

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

resource "google_project_iam_member" "keda_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.namespace}/sa/${var.service_account_name}"
  # TODO: can we limit this to just the topic/subscription?
}

# resource "google_project_iam_member" "keda_monitoring_viewer" {
#   project = var.project_id
#   role    = "roles/monitoring.viewer"
#   member  = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.namespace}/sa/${var.service_account_name}"
# }

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
      minReplicaCount = var.min_replica_count
      maxReplicaCount = var.max_replica_count
      pollingInterval = var.polling_interval_seconds
      cooldownPeriod  = var.cool_down_period_seconds
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
          type = "gcp-pubsub"
          authenticationRef = {
            name = "gcp-wi-auth"
          }
          metadata = {
            subscriptionName = var.subscription_id
            mode             = "SubscriptionSize"
            value            = tostring(var.subscription_target_per_replica)
            activationValue  = tostring(var.subscription_activation_value)
            timeHorizon      = tostring(var.subscription_time_horizon)
            valueIfNull      = "0"
          }
        }
      ]
    }
  }

  depends_on = [
    #kubernetes_manifest.keda_trigger_auth_gcp
  ]
}