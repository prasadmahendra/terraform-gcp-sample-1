# Further reading
# Access google cloud services from pod requires:
# Cluster config for workload identity:
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable

# Auth Required to mount GCS via CSI drivers:
# https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#authentication
# https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/blob/main/docs/authentication.md

locals {
  enable_kubernetes_service_based_lb = false
  managed_certificate_name_augmented = var.managed_ssl_certificate_name != null ? "${var.managed_ssl_certificate_name}-for-${var.service_name}" : null
  max_surge       = var.number_of_replicas == 1 ? "50%" : "50%"
  max_unavailable = var.number_of_replicas == 1 ? "100%" : "50%"
}

# A service account provides an identity for processes that run in a Pod.
resource "kubernetes_service_account" "kubernetes_service_account_k8_sa" {
  metadata {
    name        = "${var.service_name}-k8-sa"
    namespace   = var.kubernetes_namespace
    # Annotate the Kubernetes service account with the email address of the IAM service account.
    annotations = {
      "iam.gke.io/gcp-service-account" = var.google_service_account_for_the_service.email
    }
  }
}

# Allow the Kubernetes service account to impersonate the IAM service account by
# adding an IAM policy binding between the two service accounts. This binding allows
# the Kubernetes service account to act as the IAM service account.
#resource "google_service_account_iam_binding" "service_account_iam_binding" {
#  service_account_id = var.google_service_account_id_for_the_service
#  role               = "roles/iam.workloadIdentityUser"
#  members            = [
#    "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name}]"
#  ]
#}
resource "google_service_account_iam_member" "admin-account-iam" {
  service_account_id = var.google_service_account_for_the_service.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name}]"
}

resource "kubernetes_deployment_v1" "kubernetes_app_deployment" {
  metadata {
    name      = var.service_name
    namespace = var.kubernetes_namespace
  }
  lifecycle {
    ignore_changes = [
      spec[0].template[0].metadata[0].annotations["kubectl.kubernetes.io/restartedAt"],
      # Replicas are owned by the KEDA/HPA autoscaler at runtime; var.number_of_replicas
      # is only the initial count. Ignore so a -refresh=true plan does not try to revert
      # the autoscaler (e.g. scaling a live service 12 -> 3).
      spec[0].replicas,
    ]
  }
  spec {
    replicas = var.number_of_replicas
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = local.max_surge
        max_unavailable = local.max_unavailable
      }
    }
    min_ready_seconds = 5
    progress_deadline_seconds = 120
    selector {
      match_labels = {
        app = var.service_name
      }
    }
    template {
      metadata {
        labels = {
          app = var.service_name
        }
        annotations = {
          "gke-gcsfuse/volumes"                 = length(var.persistent_volumes) > 0 ? "true" : "false"
          #
          # The gcsfuse sidecar container can consume unlimited resources on Standard clusters.
          # If you pass "0" to the pod annotations, the sidecar container will have no resource
          # limit set, which makes the pod burstable.
          # https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/issues/61
          #
          "gke-gcsfuse/cpu-limit"               = "0"
          "gke-gcsfuse/memory-limit"            = "0"
          "gke-gcsfuse/ephemeral-storage-limit" = "0"
        }
      }
      spec {
        node_selector = {
          "cloud.google.com/gke-accelerator" = var.gpu_accelerator_type
        }
        dynamic "toleration" {
          # allow pods that aren't using the GPU to be scheduled on nodes that have the GPU
          for_each = var.gpu_accelerator_type == null && var.gpu_accelerator_type_scheduling_disallowed == false ? [1] : []
          content {
            key      = "nvidia.com/gpu"
            operator = "Equal"
            value    = "present"
            effect   = "NoSchedule"
          }
        }
        container {
          image             = "${var.docker_image}:${var.docker_image_tag}"
          image_pull_policy = "Always"
          name              = var.container_dns_label
          command           = var.container_command
          args              = var.container_command_args
          env {
            name  = "ENV"
            value = var.environment
          }
          env {
            name  = "PORT"
            value = var.container_port
          }
          env {
            name = "DD_ENV"
            value = var.environment
          }
          dynamic "env" {
            for_each = var.profiling_enabled ? [] : [] # disabled for now
            content {
              name  = "DD_PROFILING_ENABLED"
              value = "true"
            }
          }
          env {
            name = "DD_LOGS_INJECTION"
            value = "true"
          }
          env {
            name = "DD_SERVICE"
            value = var.service_name
          }
          env {
            name = "DD_AGENT_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          env {
            name = "DD_TRACE_DEBUG"
            value = "false"
          }
          env {
            name  = "DD_TRACE_ENABLED"
            value = var.apm_enabled ? "true" : "false"
          }
          env {
            name  = "DD_RUNTIME_METRICS_ENABLED"
            value = "true"
          }
          env {
            name = "STATSD_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          env {
            name  = "STATSD_PORT"
            value = "8125"
          }
          dynamic "env" {
            for_each = var.env
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          dynamic "security_context" {
            for_each = var.run_as_non_root ? [1] : []
            content {
              run_as_non_root = var.run_as_non_root
            }
          }
          resources {
            # Describes the maximum amount of compute resources allowed.
            limits = {
              "nvidia.com/gpu" = var.limits_nvidia_gpus
              "cpu"            = var.limits_cpus
              "memory"         = var.limits_memory
            }
            # Describes the minimum amount of compute resources required.
            requests = {
              "nvidia.com/gpu" = var.requests_nvidia_gpus
              "cpu"            = var.requests_cpus
              "memory"         = var.requests_memory
            }
          }
          dynamic "volume_mount" {
            for_each = var.persistent_volumes
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.mount_path
              read_only  = volume_mount.value.read_only
            }
          }
          dynamic "volume_mount" {
            for_each = var.set_shm_to_memory ? [1] : []
            content {
              name       = "dshm"
              mount_path = "/dev/shm"
            }
          }
          volume_mount {
            name       = "apmsocketpath"
            mount_path = "/var/run/datadog/apm"
          }
          dynamic "liveness_probe" {
            for_each = var.liveness_probe != null ? [var.liveness_probe] : []
            content {
              dynamic "grpc" {
                for_each = liveness_probe.value.grpc != null ? [liveness_probe.value.grpc] : []
                content {
                  service = grpc.value.service_name
                  port    = grpc.value.port
                }
              }
              initial_delay_seconds = liveness_probe.value.initial_delay_seconds
              period_seconds        = liveness_probe.value.period_seconds
              failure_threshold     = liveness_probe.value.failure_threshold
              success_threshold     = liveness_probe.value.success_threshold
              timeout_seconds       = liveness_probe.value.timeout_seconds
            }
          }
          dynamic "readiness_probe" {
            for_each = var.readiness_probe != null ? [var.readiness_probe] : []
            content {
              dynamic "grpc" {
                for_each = readiness_probe.value.grpc != null ? [readiness_probe.value.grpc] : []
                content {
                  service = grpc.value.service_name
                  port    = grpc.value.port
                }
              }
              initial_delay_seconds = readiness_probe.value.initial_delay_seconds
              period_seconds        = readiness_probe.value.period_seconds
              failure_threshold     = readiness_probe.value.failure_threshold
              success_threshold     = readiness_probe.value.success_threshold
              timeout_seconds       = readiness_probe.value.timeout_seconds
            }
          }
          port {
            container_port = var.container_port
          }
        }
        dynamic "container" {
          for_each = var.cloudsql_databases
          content {
            image             = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.18.2"
            image_pull_policy = "IfNotPresent"
            name              = "cloudsql-proxy"
            args              = [
              # If connecting from a VPC-native GKE cluster, you can use the
              # following flag to have the proxy connect over private IP
              "--private-ip",
              # Enable structured logging with LogEntry format:
              "--structured-logs",
              "--port=${container.value.port}",
              container.value.instance_connection_name
            ]
            security_context {
              run_as_non_root = true
            }
          }
        }
        dynamic "volume" {
          for_each = var.persistent_volumes
          content {
            name = volume.value.name
            persistent_volume_claim {
              claim_name = volume.value.persistent_volume_claim_name
            }
          }
        }
        # set_shm_to_memory
        dynamic "volume" {
          for_each = var.set_shm_to_memory ? [1] : []
          content {
            name = "dshm"
            empty_dir {
              medium = "Memory"
            }
          }
        }
        volume {
          name = "apmsocketpath"
          host_path {
            path = "/var/run/datadog/apm"
          }
        }
        service_account_name = kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name
      }
    }
  }
}

# Setting up traffic director:
# https://cloud.google.com/traffic-director/docs/set-up-proxyless-gke#gcloud_2
resource "kubernetes_service_v1" "service_cluster_ip" {
  #depends_on = [kubernetes_manifest.kubernetes_manifest_ingress_backend_config]
  metadata {
    name      = "${var.service_name}-grpc-server"
    namespace = var.kubernetes_namespace
    annotations = {
      "cloud.google.com/neg" = "{\"exposed_ports\":{\"${var.service_port}\":{\"name\": \"${var.service_name}-grpc-server\"}}}"
    }
    labels    = {
      sd-import = "true"
    }
  }
  lifecycle {
    # ignore meta-data annotations changes for "cloud.google.com/neg-status"
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg-status"]
    ]
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.kubernetes_app_deployment.spec.0.template.0.metadata.0.labels.app
    }
    type = "ClusterIP"
    port {
      protocol    = "TCP"
      port        = var.service_port
      target_port = var.container_port
    }
  }
}
