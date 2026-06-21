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
  spot_capacity_enabled              = var.number_of_replicas_spot_capacity != null
  number_of_replicas                 = var.number_of_replicas
  number_of_replicas_total           = var.number_of_replicas + (var.number_of_replicas_spot_capacity != null && var.number_of_replicas_spot_capacity > 0 ? var.number_of_replicas_spot_capacity : 0)
  number_of_replicas_spot_capacity   = var.number_of_replicas_spot_capacity != null && var.number_of_replicas_spot_capacity > 0 ? var.number_of_replicas_spot_capacity : 0
  max_surge                          = var.max_surge != null ? var.max_surge : (local.number_of_replicas_total == 1 ? "50%" : "50%")
  max_unavailable                    = var.max_unavailable != null ? var.max_unavailable : (local.number_of_replicas_total == 1 ? "100%" : "50%")
}

# A service account provides an identity for processes that run in a Pod.
resource "kubernetes_service_account" "kubernetes_service_account_k8_sa" {
  metadata {
    name = "${var.service_name}-k8-sa"
    namespace = var.kubernetes_namespace
    # Annotate the Kubernetes service account with the email address of the IAM service account.
    annotations = {
      "iam.gke.io/gcp-service-account" = var.google_service_account_for_the_service.email
    }
  }
}

data "google_compute_subnetwork" "subnet" {
  name   = var.subnet
  region = var.region
}

resource "google_service_account_iam_member" "admin-account-iam" {
  service_account_id = var.google_service_account_for_the_service.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name}]"
}

# config map
resource "kubernetes_config_map" "kubernetes_config_map" {
  count = length(var.config_maps)
  metadata {
    name      = "${var.service_name}-${var.config_maps[count.index].name}"
    namespace = var.kubernetes_namespace
    labels = {
      app = var.service_name
    }
  }
  data = var.config_maps[count.index].data
}

# Tolerating taints:
# https://cloud.google.com/kubernetes-engine/docs/how-to/node-taints
# https://cloud.google.com/kubernetes-engine/docs/how-to/node-taints#effects
resource "kubernetes_deployment_v1" "kubernetes_app_deployment" {
  count = 1
  depends_on = [
    #kubernetes_config_map.kubernetes_config_map,
    kubernetes_service_account.kubernetes_service_account_k8_sa,
  ]
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
    progress_deadline_seconds = var.progress_deadline_seconds
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
        annotations = merge (
          {
            "gke-gcsfuse/volumes"                 = "true"
            #
            # The gcsfuse sidecar container can consume unlimited resources on Standard clusters.
            # If you pass "0" to the pod annotations, the sidecar container will have no resource
            # limit set, which makes the pod burstable.
            # https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/issues/61
            #
            "gke-gcsfuse/cpu-limit"               = "0"
            "gke-gcsfuse/memory-limit"            = "0"
            "gke-gcsfuse/ephemeral-storage-limit" = "0"
          },
          var.pod_annotations
        )
      }
      spec {
        node_selector = merge (
          {
            "cloud.google.com/gke-accelerator" = var.gpu_accelerator_type
          },
          var.gpu_nodepool != null ? {
            "cloud.google.com/gke-nodepool" = var.gpu_nodepool
          } : {}
        )
        dynamic "container" {
          for_each = var.cloudsql_databases
          content {
            image             = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.18.2"
            image_pull_policy = "IfNotPresent"
            name              = "cloudsql-proxy"
            args = [
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
            name  = "DD_ENV"
            value = var.environment
          }
          dynamic "env" {
            for_each = var.profiling_enabled ? [1] : [] # disabled for now
            content {
              name  = "DD_PROFILING_ENABLED"
              value = "true"
            }
          }
          env {
            name  = "DD_LOGS_INJECTION"
            value = "true"
          }
          env {
            name  = "DD_SERVICE"
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
            name  = "DD_TRACE_LOG_LEVEL"
            value = "WARNING"
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
            for_each = var.config_maps
            content {
              name       = "${var.service_name}-${volume_mount.value.name}-volume"
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
          dynamic "volume_mount" {
            for_each = var.enable_local_ssd ? [1] : []
            content {
              name = "local-ssd"
              mount_path = "/data/ssd"
            }
          }
          volume_mount {
            name       = "apmsocketpath"
            mount_path = "/var/run/datadog/apm"
          }
          dynamic "liveness_probe" {
            for_each = var.liveness_probe != null ? [var.liveness_probe] : []
            content {
              dynamic "http_get" {
                for_each = liveness_probe.value.http_get != null ? [liveness_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port
                  dynamic "http_header" {
                    for_each = http_get.value.http_headers != null ? http_get.value.http_headers : []
                    content {
                      name  = http_header.value.name
                      value = http_header.value.value
                    }
                  }
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
              dynamic "http_get" {
                for_each = readiness_probe.value.http_get != null ? [readiness_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port
                  dynamic "http_header" {
                    for_each = http_get.value.http_headers != null ? http_get.value.http_headers : []
                    content {
                      name  = http_header.value.name
                      value = http_header.value.value
                    }
                  }
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
          for_each = var.sidecar_containers
          content {
            image             = container.value.image
            image_pull_policy = container.value.image_pull_policy
            name              = container.value.name
            command           = container.value.command
            args              = container.value.args
            dynamic "env" {
              for_each = container.value.env
              content {
                name  = env.key
                value = env.value
              }
            }
            dynamic "resources" {
              for_each = length(container.value.limits) > 0 || length(container.value.requests) > 0 ? [1] : []
              content {
                limits   = container.value.limits
                requests = container.value.requests
              }
            }
            dynamic "port" {
              for_each = container.value.port != null ? [container.value.port] : []
              content {
                container_port = port.value
              }
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
        dynamic "volume" {
          for_each = var.config_maps
          content {
            name = "${var.service_name}-${volume.value.name}-volume"
            config_map {
              name = "${var.service_name}-${volume.value.name}"
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
        # mount_local_ssd
        dynamic "volume" {
          for_each = var.enable_local_ssd ? [1] : []
          content {
            name = "local-ssd"
            host_path {
              path = "/mnt/stateful_partition"
              type = "Directory"
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

resource "kubernetes_deployment_v1" "kubernetes_app_deployment_spot_capacity" {
  count = local.spot_capacity_enabled ? 1 : 0
  depends_on = [
    kubernetes_service_account.kubernetes_service_account_k8_sa,
  ]
  metadata {
    name      = "${var.service_name}-spot-cap"
    namespace = var.kubernetes_namespace
  }
  lifecycle {
    ignore_changes = [
      spec[0].template[0].metadata[0].annotations["kubectl.kubernetes.io/restartedAt"],
      # Replicas are owned by the KEDA/HPA autoscaler at runtime; var.number_of_replicas_spot_capacity
      # is only the initial count. Ignore so a -refresh=true plan does not try to revert
      # the autoscaler (e.g. scaling a live service 12 -> 3).
      spec[0].replicas,
    ]
  }
  spec {
    replicas = var.number_of_replicas_spot_capacity
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = local.max_surge
        max_unavailable = local.max_unavailable
      }
    }
    progress_deadline_seconds = var.progress_deadline_seconds
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
        annotations = merge (
          {
            "gke-gcsfuse/volumes"                 = "true"
            #
            # The gcsfuse sidecar container can consume unlimited resources on Standard clusters.
            # If you pass "0" to the pod annotations, the sidecar container will have no resource
            # limit set, which makes the pod burstable.
            # https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/issues/61
            #
            "gke-gcsfuse/cpu-limit"               = "0"
            "gke-gcsfuse/memory-limit"            = "0"
            "gke-gcsfuse/ephemeral-storage-limit" = "0"
          },
          var.pod_annotations
        )
      }
      spec {
        node_selector = {
          # Custom Compute Classes cannot be used along labels with keys:
          # "cloud.google.com/gke-accelerator" = var.gpu_accelerator_type
          "cloud.google.com/compute-class"   = var.spot_capacity_compute_class
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
            name  = "DD_ENV"
            value = var.environment
          }
          dynamic "env" {
            for_each = var.profiling_enabled ? [1] : [] # disabled for now
            content {
              name  = "DD_PROFILING_ENABLED"
              value = "true"
            }
          }
          env {
            name  = "DD_LOGS_INJECTION"
            value = "true"
          }
          env {
            name  = "DD_SERVICE"
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
            for_each = var.config_maps
            content {
              name       = "${var.service_name}-${volume_mount.value.name}-volume"
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
          dynamic "volume_mount" {
            for_each = var.enable_local_ssd ? [1] : []
            content {
              name = "local-ssd"
              mount_path = "/data/ssd"
            }
          }
          volume_mount {
            name       = "apmsocketpath"
            mount_path = "/var/run/datadog/apm"
          }
          dynamic "liveness_probe" {
            for_each = var.liveness_probe != null ? [var.liveness_probe] : []
            content {
              dynamic "http_get" {
                for_each = liveness_probe.value.http_get != null ? [liveness_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port
                  dynamic "http_header" {
                    for_each = http_get.value.http_headers != null ? http_get.value.http_headers : []
                    content {
                      name  = http_header.value.name
                      value = http_header.value.value
                    }
                  }
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
              dynamic "http_get" {
                for_each = readiness_probe.value.http_get != null ? [readiness_probe.value.http_get] : []
                content {
                  path = http_get.value.path
                  port = http_get.value.port
                  dynamic "http_header" {
                    for_each = http_get.value.http_headers != null ? http_get.value.http_headers : []
                    content {
                      name  = http_header.value.name
                      value = http_header.value.value
                    }
                  }
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
          for_each = var.sidecar_containers
          content {
            image             = container.value.image
            image_pull_policy = container.value.image_pull_policy
            name              = container.value.name
            command           = container.value.command
            args              = container.value.args
            dynamic "env" {
              for_each = container.value.env
              content {
                name  = env.key
                value = env.value
              }
            }
            dynamic "resources" {
              for_each = length(container.value.limits) > 0 || length(container.value.requests) > 0 ? [1] : []
              content {
                limits   = container.value.limits
                requests = container.value.requests
              }
            }
            dynamic "port" {
              for_each = container.value.port != null ? [container.value.port] : []
              content {
                container_port = port.value
              }
            }
          }
        }
        dynamic "container" {
          for_each = var.cloudsql_databases
          content {
            image             = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.18.2"
            image_pull_policy = "IfNotPresent"
            name              = "cloudsql-proxy"
            args = [
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
        dynamic "volume" {
          for_each = var.config_maps
          content {
            name = "${var.service_name}-${volume.value.name}-volume"
            config_map {
              name = "${var.service_name}-${volume.value.name}"
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
        # mount_local_ssd
        dynamic "volume" {
          for_each = var.enable_local_ssd ? [1] : []
          content {
            name = "local-ssd"
            host_path {
              path = "/mnt/stateful_partition"
              type = "Directory"
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

resource "kubernetes_pod_disruption_budget_v1" "pdb" {
  count = var.pdb_min_available != null ? 1 : 0
  metadata {
    name      = "${var.service_name}-pdb"
    namespace = var.kubernetes_namespace
  }
  spec {
    min_available = var.pdb_min_available
    selector {
      match_labels = {
        app = var.service_name
      }
    }
  }
}

# https://cloud.google.com/kubernetes-engine/docs/concepts/service
resource "kubernetes_service" "service_external_lb" {

  count = local.enable_kubernetes_service_based_lb && var.is_public ? 1 : 0
  metadata {
    name      = "${var.service_name}-external-lb"
    namespace = var.kubernetes_namespace
    annotations = {
    }
  }
  spec {
    selector = {
      app = var.service_name # kubernetes_deployment_v1.kubernetes_app_deployment.spec.0.template.0.metadata.0.labels.app
    }
    type = "LoadBalancer"
    port {
      port        = var.service_port
      target_port = var.container_port
    }
  }
}

resource "kubernetes_service_v1" "service_private_lb" {

  metadata {
    name      = "${var.service_name}-http-server"
    namespace = var.kubernetes_namespace
    annotations = {
      "cloud.google.com/load-balancer-type" = "Internal"
      "cloud.google.com/neg"                = "{\"exposed_ports\": {\"443\":{}}}"
      "controller.autoneg.dev/neg"          = "{\"backend_services\":{\"443\":[{\"name\":\"${var.service_name}-https\",\"max_rate_per_endpoint\":100}]}}"
    }
    labels = {
      app       = var.service_name # kubernetes_deployment_v1.kubernetes_app_deployment.spec.0.template.0.metadata.0.labels.app
      sd-import = "true"
    }
  }
  lifecycle {
    # ignore meta-data annotations changes for controller-managed annotations:
    # - "cloud.google.com/neg-status" is written back by the NEG controller
    # - "networking.gke.io/backend-service" is written back by the autoneg controller
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg-status"],
      metadata[0].annotations["networking.gke.io/backend-service"]
    ]
  }
  spec {
    selector = {
      app = var.service_name # kubernetes_deployment_v1.kubernetes_app_deployment.spec.0.template.0.metadata.0.labels.app
    }
    type = "LoadBalancer"
    port {
      port        = var.service_port
      target_port = var.container_port
    }
  }
}

resource "kubernetes_service_v1" "service_node_port" {
  depends_on = [kubernetes_manifest.kubernetes_manifest_ingress_backend_config]
  metadata {
    name      = "${var.service_name}-nodeport"
    namespace = var.kubernetes_namespace
    labels = {
      app = var.service_name # kubernetes_deployment_v1.kubernetes_app_deployment.spec.0.template.0.metadata.0.labels.app
    }
    annotations = {
      "cloud.google.com/backend-config" : "{\"default\": \"${var.service_name}-nodeport-backend-config\", \"ports\": {\"${var.container_port}\":\"${var.service_name}-nodeport-backend-config\"}}"
      "cloud.google.com/neg" : "{\"ingress\": true}"
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
      app = var.service_name # kubernetes_deployment_v1.kubernetes_app_deployment.spec.0.template.0.metadata.0.labels.app
    }
    type = "NodePort"
    port {
      port        = var.service_port
      target_port = var.container_port
    }
  }
}

# ingress gateway below needs this to be configured for /health checks (defaults to / otherwise!)
resource "kubernetes_manifest" "kubernetes_manifest_ingress_backend_config" {
  count    = var.is_public == true ? 1 : 0
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "${var.service_name}-nodeport-backend-config"
      namespace = var.kubernetes_namespace
    }
    # spec-level `timeoutSec` is the LB backend-request timeout (distinct from
    # healthCheck.timeoutSec below). Opt-in: omitted unless the caller sets
    # `backend_request_timeout_sec`, so other services keep GCP's 30s default.
    spec = merge({
      # CloudArmor security policy (only for public services, internal services do not need it/don't support it)
      securityPolicy = {
        name = var.backend_security_policy_name
      }
      healthCheck = {
        checkIntervalSec   = 10
        timeoutSec         = 10
        healthyThreshold   = 3
        unhealthyThreshold = 2
        type               = "HTTP"
        requestPath        = var.custom_backend_health_endpoint != null ? var.custom_backend_health_endpoint : "/health"
      }
    }, var.backend_request_timeout_sec == null ? {} : { timeoutSec = var.backend_request_timeout_sec })
  }
  field_manager {
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "kubernetes_manifest_ingress_backend_config_without_cloud_armor" {
  count    = var.is_public == false ? 1 : 0
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "${var.service_name}-nodeport-backend-config"
      namespace = var.kubernetes_namespace
    }
    spec = {
      healthCheck = {
        checkIntervalSec   = 10
        timeoutSec         = 10
        healthyThreshold   = 3
        unhealthyThreshold = 2
        type               = "HTTP"
        requestPath        = var.custom_backend_health_endpoint != null ? var.custom_backend_health_endpoint : "/health"
      }
    }
  }
  field_manager {
    force_conflicts = true
  }
}

# ingress gateway below needs this for the TLS certificate
resource "kubernetes_manifest" "kubernetes_manifest_managed_cert_config" {
  count    = local.managed_certificate_name_augmented != null ? 1 : 0
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = local.managed_certificate_name_augmented
      namespace = var.kubernetes_namespace
    }
    spec = {
      domains = [var.service_fqdn]
    }
  }
  field_manager {
    force_conflicts = true
  }
}

resource "google_compute_global_address" "compute_global_address" {
  count   = var.is_public ? 1 : 0
  project = var.project_id
  name    = "public-ip-addr-${var.service_name}"
}

resource "google_compute_address" "compute_private_address" {
  count   = var.is_public ? 0 : 1
  name         = "private-ip-addr-${var.service_name}"
  address_type = "INTERNAL"
  subnetwork   = var.subnet
  #region       = var.reg
  #subnetwork   = var. data.google_compute_subnetwork.subnet.self_link
  # purpose can be omitted for GKE ILB; leaving unset keeps it flexible.
}

# https://stackoverflow.com/questions/70670084/configuring-the-health-check-of-a-kubernetes-ingress-with-terraform
resource "kubernetes_ingress_v1" "service_ingress" {
  count = var.is_public ? 1 : 1
  depends_on = [
    kubernetes_manifest.kubernetes_manifest_ingress_backend_config,
    kubernetes_manifest.kubernetes_manifest_managed_cert_config
  ]
  metadata {
    name      = "${var.service_name}-ingress"
    namespace = var.kubernetes_namespace
    annotations = {
      "kubernetes.io/ingress.class"            = var.is_public ? "gce" : "gce-internal"
      "kubernetes.io/ingress.global-static-ip-name" = var.is_public ? google_compute_global_address.compute_global_address[0].name : google_compute_address.compute_private_address[0].name
      # https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-multi-ssl#gke_multi_ssl_2-
      "networking.gke.io/managed-certificates" = local.managed_certificate_name_augmented
      # Disable http and allow only HTTPS
      # https://cloud.google.com/kubernetes-engine/docs/concepts/ingress-xlb
      "kubernetes.io/ingress.allow-http"       = var.is_public ? false : true # managed_certificate_name_augmented doesn't work with HTTP "gce-internal". Figure out why!
    }
  }
  spec {
    default_backend {
      service {
        name = "${var.service_name}-nodeport" # kubernetes_service_v1.service_internal_lb.metadata.0.name
        port {
          number = var.service_port
        }
      }
    }
    rule {
      host = var.service_fqdn
      http {
        path {
          #path = "/*"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "${var.service_name}-nodeport" # kubernetes_service_v1.service_internal_lb.metadata.0.name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }
  }
}

module "dns_record_set_public" {
  count    = var.is_public ? 1 : 0
  source   = "../create_dns_recordset"
  dns_zone = var.public_dns_zone_name
  name     = "${var.service_fqdn}."
  rrdatas = [
    # kubernetes_ingress_v1.service_ingress.status.0.load_balancer.0.ingress.0.ip
    google_compute_global_address.compute_global_address[0].address
  ]
  ttl  = 300
  type = "A"
}

module "dns_record_set_private" {
  count = var.is_public == false ? 1 : 0
  source = "../create_dns_recordset"
  dns_zone = {
    name     = var.private_dns_zone_name
    provider = "google"
  }
  name = "${var.service_fqdn}."
  rrdatas = [
    #kubernetes_ingress_v1.service_ingress[0].status.0.load_balancer.0.ingress.0.ip
    #google_compute_global_address.compute_global_address[0].address
    google_compute_address.compute_private_address[0].address
  ]
  ttl  = 300
  type = "A"
}

resource "google_dns_record_set" "dns_record_set_private" {
  # This is required for GKE to resolve public DNS entries
  count = var.is_public ? 1 : 0
  depends_on = [
    kubernetes_ingress_v1.service_ingress,
    google_compute_global_address.compute_global_address
  ]
  name         = "${var.service_fqdn}."
  managed_zone = var.private_dns_zone_name
  type         = "A"
  ttl          = 300
  rrdatas = [
    google_compute_global_address.compute_global_address[0].address
  ]
}