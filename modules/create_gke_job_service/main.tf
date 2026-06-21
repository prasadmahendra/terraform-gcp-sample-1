# Further reading
# Access google cloud services from pod requires:
# Cluster config for workload identity:
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#enable

# Auth Required to mount GCS via CSI drivers:
# https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#authentication
# https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/blob/main/docs/authentication.md
#
# Dynamic Workload Scheduler:
# https://cloud.google.com/kubernetes-engine/docs/how-to/provisioningrequest
# https://cloud.google.com/blog/products/compute/introducing-dynamic-workload-scheduler
#

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

locals {
  max_surge                     = var.number_of_replicas == 1 ? "50%" : "50%"
  max_unavailable               = var.number_of_replicas == 1 ? "100%" : "50%"
  environment_variables         = var.env != null ? var.env : []
  cloudsql_databases            = var.cloudsql_databases != null ? var.cloudsql_databases : []
  read_only_persistent_volumes  = var.persistent_volumes != null ? [for pv in var.persistent_volumes : pv if pv.read_only == true] : []
  read_write_persistent_volumes = var.persistent_volumes != null ? [for pv in var.persistent_volumes : pv if pv.read_only == false] : []
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

resource "kubernetes_role" "pod_self_patch" {
  metadata {
    name      = "pod-self-patch"
    namespace = var.kubernetes_namespace
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "patch", "update"]
    # optionally restrict via resource_names if you know the pod name
    # resource_names = ["my-pod-name"]
  }
}

resource "kubernetes_role_binding" "pod_self_patch_binding" {
  metadata {
    name      = "pod-self-patch-binding"
    namespace = var.kubernetes_namespace
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name
    namespace = var.kubernetes_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.pod_self_patch.metadata[0].name
  }
}

resource "google_service_account_iam_member" "admin-account-iam" {
  service_account_id = var.google_service_account_for_the_service.id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name}]"
}

resource "kubernetes_cluster_role" "datadog_kubelet_access" {
  metadata {
    name = "${var.service_name}-datadog-kubelet-access"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/proxy", "nodes", "pods", "services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "datadog_kubelet_access" {
  metadata {
    name = "${var.service_name}-datadog-kubelet-access"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.datadog_kubelet_access.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name
    namespace = var.kubernetes_namespace
  }
}

resource "kubernetes_config_map" "datadog_vllm_config" {
  metadata {
    name      = "${var.service_name}-datadog-vllm-config"
    namespace = var.kubernetes_namespace
  }

  data = {
    "prometheus.yaml" = <<-EOT
      init_config:
      instances:
        - prometheus_url: http://localhost:8002/metrics
          namespace: vllm
          metrics:
            - "*"
    EOT
  }
}

resource "kubectl_manifest" "sample_job" {
  # kubectl_manifest keeps the manifest as an opaque YAML string, so GKE/k8s API
  # schema changes (e.g. the k8s 1.34 projected-volume podCertificate field) don't
  # break the plan with "Failed to update proposed state from prior state".
  server_side_apply = true
  force_conflicts   = true # override field-ownership conflicts (was field_manager.force_conflicts)
  # kueue flips spec.suspend and mutates the pod template annotations at runtime;
  # ignore them so Terraform doesn't fight the controller (was lifecycle.ignore_changes).
  ignore_fields = [
    "spec.suspend",
    "spec.template.metadata.annotations",
  ]
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = var.service_name
      namespace = var.kubernetes_namespace
      labels = {
        "kueue.x-k8s.io/queue-name" = "dws-local-queue" # "dws-cluster-queue" # "dws-local-queue"
      }
      annotations = {
        "provreq.kueue.x-k8s.io/maxRunDurationSeconds" = "3600"
      }
    }
    spec = {
      parallelism = 1
      completions = 1
      suspend     = true
      template = {
        metadata = {
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
        spec = {
          nodeSelector = {
            "cloud.google.com/gke-accelerator" = var.gpu_accelerator_type
            "cloud.google.com/gke-nodepool"    = var.target_node_pool_name
          }
          tolerations = [
            {
              key      = "nvidia.com/gpu"
              operator = "Exists"
              effect   = "NoSchedule"
            }
          ]
          serviceAccountName = kubernetes_service_account.kubernetes_service_account_k8_sa.metadata[0].name
          containers = concat(
            [
              merge({
                name              = var.service_name
                # image = "gcr.io/k8s-staging-perf-tests/sleep:v0.0.3"
                # args = ["120s"]
                image             = "${var.docker_image}:${var.docker_image_tag}"
                image_pull_policy = "IfNotPresent"
                command           = var.container_command
                args              = var.container_command_args
                env               = concat(
                  [
                    for env in local.environment_variables : {
                      name  = env.name
                      value = env.value
                    }
                  ],
                  [
                    {
                      name  = "PORT"
                      value = var.container_port
                    },
                    {
                      name  = "DD_ENV"
                      value = var.environment
                    },
                    {
                      name  = "DD_PROFILING_ENABLED"
                      value = "true"
                    },
                    {
                      name  = "DD_LOGS_INJECTION"
                      value = "true"
                    },
                    {
                      name  = "DD_SERVICE"
                      value = var.service_name
                    },
                    {
                      name = "DD_AGENT_HOST"
                      value = "localhost"
                    },
                    {
                      name  = "DD_TRACE_ENABLED"
                      value = var.apm_enabled ? "true" : "false"
                    },
                    {
                      name  = "DD_RUNTIME_METRICS_ENABLED"
                      value = "true"
                    },
                    {
                      name = "STATSD_HOST"
                      value = "localhost"
                    },
                    {
                      name  = "STATSD_PORT"
                      value = "8125"
                    }
                  ]
                )
                
                volumeMounts = concat(
                  [
                    for pv in local.read_only_persistent_volumes : {
                      name      = pv.name
                      mountPath = pv.mount_path
                      readOnly  = true
                    }
                  ],
                  [
                    for pv in local.read_write_persistent_volumes : {
                      name      = pv.name
                      mountPath = pv.mount_path
                    }
                  ],
                  [
                    {
                      name = "local-ssd"
                      mountPath = "/data/ssd"
                    },
                    {
                      name = "apmsocketpath"
                      mountPath = "/var/run/datadog/apm"
                    }
                  ],
                  var.set_shm_to_memory ? [
                    {
                      name = "dshm"
                      mountPath = "/dev/shm"
                    }
                  ] : [],
                )
                resources = {
                  requests = {
                    cpu              = var.requests_cpus
                    memory           = var.requests_memory
                    "nvidia.com/gpu" = var.requests_nvidia_gpus
                  }
                  limits = {
                    cpu              = var.limits_cpus
                    memory           = var.limits_memory
                    "nvidia.com/gpu" = var.limits_nvidia_gpus
                  }
                },
                port = {
                  containerPort = var.container_port
                }
              },
              var.liveness_probe != null ? {
                livenessProbe = merge(
                  try(var.liveness_probe.grpc, null) != null ? {
                    grpc = {
                      service = var.liveness_probe.grpc.service_name
                      port    = var.liveness_probe.grpc.port
                    }
                  } : {},
                  try(var.liveness_probe.http_get, null) != null ? {
                    httpGet = merge(
                      {
                        path = var.liveness_probe.http_get.path
                        port = var.liveness_probe.http_get.port
                      },
                      try(var.liveness_probe.http_get.http_headers, null) != null ? {
                        httpHeaders = [
                          for header in var.liveness_probe.http_get.http_headers : {
                            name  = header.name
                            value = header.value
                          }
                        ]
                      } : {}
                    )
                  } : {},
                  {
                    initialDelaySeconds = var.liveness_probe.initial_delay_seconds
                    periodSeconds       = var.liveness_probe.period_seconds
                    failureThreshold    = var.liveness_probe.failure_threshold
                    successThreshold    = var.liveness_probe.success_threshold
                    timeoutSeconds      = var.liveness_probe.timeout_seconds
                  }
                )
              } : {},
              var.readiness_probe != null ? {
                readinessProbe = merge(
                  try(var.readiness_probe.grpc, null) != null ? {
                    grpc = {
                      service = var.readiness_probe.grpc.service_name
                      port    = var.readiness_probe.grpc.port
                    }
                  } : {},
                  try(var.readiness_probe.http_get, null) != null ? {
                    httpGet = merge(
                      {
                        path = var.readiness_probe.http_get.path
                        port = var.readiness_probe.http_get.port
                      },
                      try(var.readiness_probe.http_get.http_headers, null) != null ? {
                        httpHeaders = [
                          for header in var.readiness_probe.http_get.http_headers : {
                            name  = header.name
                            value = header.value
                          }
                        ]
                      } : {}
                    )
                  } : {},
                  {
                    initialDelaySeconds = var.readiness_probe.initial_delay_seconds
                    periodSeconds       = var.readiness_probe.period_seconds
                    failureThreshold    = var.readiness_probe.failure_threshold
                    successThreshold    = var.readiness_probe.success_threshold
                    timeoutSeconds      = var.readiness_probe.timeout_seconds
                  }
                )
              } : {}
            ),
              {
                name  = "datadog-agent"
                image = "gcr.io/datadoghq/agent:7.51.0"

                env = [
                  {
                    name = "DD_API_KEY"
                    value = var.datadog_api_key
                  },
                  {
                    name = "DD_APP_KEY"
                    value = var.datadog_app_key
                  },
                  {
                    name  = "DD_SITE"
                    value = var.datadog_site
                  },
                  {
                    name  = "DD_PROMETHEUS_SCRAPE_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_PROCESS_AGENT_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_LOGS_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_APM_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_DOGSTATSD_PORT"
                    value = "8125"
                  },
                  {
                    name  = "DD_CLOUD_PROVIDER"
                    value = "gcp"
                  },
                  {
                    name  = "DD_GCP_PROJECT_ID"
                    value = var.project_id
                  },
                  {
                    name  = "DD_GCP_GCE_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_GCP_GKE_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_GCP_CLOUD_SQL_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_GCP_PUBSUB_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_COLLECT_KUBERNETES_EVENTS"
                    value = "true"
                  },
                  {
                    name  = "DD_KUBELET_TLS_VERIFY"
                    value = "false"
                  },
                  {
                    name  = "DD_KUBERNETES_KUBELET_HOST"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "status.hostIP"
                      }
                    }
                  },
                  {
                    name  = "DD_KUBERNETES_KUBELET_NODENAME"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "spec.nodeName"
                      }
                    }
                  },
                  {
                    name  = "DD_KUBERNETES_POD_UID"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "metadata.uid"
                      }
                    }
                  },
                  {
                    name  = "DD_KUBERNETES_POD_NAME"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "metadata.name"
                      }
                    }
                  },
                  {
                    name  = "DD_KUBERNETES_NAMESPACE"
                    valueFrom = {
                      fieldRef = {
                        fieldPath = "metadata.namespace"
                      }
                    }
                  },
                  {
                    name  = "DD_PROMETHEUS_SCRAPE_SERVICES"
                    value = "true"
                  },
                  {
                    name  = "DD_PROMETHEUS_SCRAPE_ENDPOINTS"
                    value = "true"
                  },
                  {
                    name  = "DD_AUTODISCOVERY_ENABLED"
                    value = "true"
                  },
                  {
                    name  = "DD_AUTODISCOVERY_KUBERNETES_ENABLED"
                    value = "true"
                  }
                ]

                port = {
                  containerPort = 8125
                }
                
                volumeMounts = [
                  {
                    name = "apmsocketpath"
                    mountPath = "/var/run/datadog/apm"
                  },
                  {
                    name = "cgroup"
                    mountPath = "/host/sys/fs/cgroup"
                    readOnly = true
                  },
                  {
                    name = "proc"
                    mountPath = "/host/proc"
                    readOnly = true
                  },
                  {
                    name = "disk"
                    mountPath = "/host/root"
                    readOnly = true
                  },
                  {
                    name = "vllm-config"
                    mountPath = "/etc/datadog-agent/conf.d"
                    readOnly = true
                  }
                ]
                
                securityContext = {
                  runAsUser = 0
                  privileged = true
                }
              }
            ],
            [
              for cloudsql_database in var.cloudsql_databases : {
              name              = "cloudsql-proxy"
              image             = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.18.2"
              image_pull_policy = "IfNotPresent"
              args = [
                # If connecting from a VPC-native GKE cluster, you can use the
                # following flag to have the proxy connect over private IP
                "--private-ip",
                # Enable structured logging with LogEntry format:
                "--structured-logs",
                "--port=${cloudsql_database.port}",
                cloudsql_database.instance_connection_name
              ]
              security_context = {
                run_as_non_root = true
              }
            }
            ],
            [
              for sidecar in var.sidecar_containers : merge(
                {
                  name            = sidecar.name
                  image           = sidecar.image
                  imagePullPolicy = sidecar.image_pull_policy
                  command         = sidecar.command
                  args            = sidecar.args
                  env = [
                    for env_name, env_value in sidecar.env : {
                      name  = env_name
                      value = env_value
                    }
                  ]
                },
                sidecar.port != null ? {
                  port = {
                    containerPort = sidecar.port
                  }
                } : {},
                length(sidecar.limits) > 0 || length(sidecar.requests) > 0 ? {
                  resources = {
                    limits   = sidecar.limits
                    requests = sidecar.requests
                  }
                } : {}
              )
            ]
          )
          volumes = concat(
            [
              for pv in var.persistent_volumes : {
                name = pv.name
                persistentVolumeClaim = {
                  claimName = pv.persistent_volume_claim_name
                }
              }
            ],
            [
              {
                name = "local-ssd"
                hostPath = {
                  path = "/mnt/stateful_partition"
                  type = "Directory"
                }
              },
              {
                name = "apmsocketpath"
                hostPath = {
                  path = "/var/run/datadog/apm"
                }
              },
              {
                name = "cgroup"
                hostPath = {
                  path = "/sys/fs/cgroup"
                  type = "Directory"
                }
              },
              {
                name = "proc"
                hostPath = {
                  path = "/proc"
                  type = "Directory"
                }
              },
              {
                name = "disk"
                hostPath = {
                  path = "/"
                  type = "Directory"
                }
              },
              {
                name = "vllm-config"
                configMap = {
                  name = "${var.service_name}-datadog-vllm-config"
                }
              }
            ],
            var.set_shm_to_memory ? [
              {
                name = "dshm"
                emptyDir = {
                  medium = "Memory"
                }
              }
            ] : []
          )
          restartPolicy = "Never"
        }
      }
    }
  })
}