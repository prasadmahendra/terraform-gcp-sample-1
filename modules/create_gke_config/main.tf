terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# Enable Kube state metrics on the cluster
# https://www.datadoghq.com/blog/monitor-kubernetes-docker/#send-custom-metrics-to-dogstatsd
resource "kubernetes_manifest" "kube-state-metrics" {
  count = var.enable_kube_state_metrics ? 1 : 0
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "kube-state-metrics"
      namespace = "kube-system"
      labels = {
        "app.kubernetes.io/component" = "exporter"
        "app.kubernetes.io/name"      = "kube-state-metrics"
        "app.kubernetes.io/version"   = "2.10.0"
      }
    }
    spec = {
      clusterIP = "None"
      ports = [
        {
          name       = "http-metrics"
          port       = 8080
          targetPort = "http-metrics"
        },
        {
          name       = "telemetry"
          port       = 8081
          targetPort = "telemetry"
        }
      ]
      selector = {
        "app.kubernetes.io/name" = "kube-state-metrics"
      }
    }
  }
}

# run datadog on the cluster to monitor the cluster health and logs
# TODO - replace with https://docs.datadoghq.com/getting_started/containers/datadog_operator/ ?
# https://docs.datadoghq.com/containers/kubernetes/
resource "helm_release" "datadog" {
  count            = 1
  name             = "datadog-agent"
  namespace        = var.datadog_cluster_agent_namespace
  create_namespace = true
  repository       = "https://helm.datadoghq.com"
  version          = "3.83.0" # 3.132.0? pin it to avoid auto-upgrade breaking changes
  chart            = "datadog"
  # wait = false to the helm_release "datadog" resource. This tells Terraform to mark the release as successful as soon as Helm submits the update, without waiting for all pods to become ready
  # datadog updates across a large fleet of nodes can take a while!
  wait             = false #
  # Config options based on
  # https://github.com/DataDog/helm-charts/blob/main/charts/datadog/README.md#all-configuration-options
  set_sensitive {
    name  = "datadog.apiKey"
    value = var.datadog_api_key
  }
  set_sensitive {
    name  = "datadog.appKey"
    value = var.datadog_app_key
  }
  set {
    name  = "datadog.site"
    value = var.datadog_site
  }
  dynamic "set" {
    for_each = var.cloud_provider == "gcp" ? [1] : []
    content {
      name  = "providers.gke.autopilot"
      value = true
    }
  }
  dynamic "set" {
    for_each = var.cloud_provider == "gcp" ? [1] : []
    content {
      name  = "providers.gke.cos"
      value = true
    }
  }
  set {
    name  = "agents.useHostNetwork"
    value = true
  }
  set {
    name  = "agents.priorityClassCreate"
    value = true
  }
  set {
    name  = "datadog.logs.enabled"
    value = true
  }
  set {
    name  = "datadog.logs.containerCollectAll"
    value = true
  }
  set {
    name  = "datadog.leaderElection"
    value = true
  }
  set {
    name  = "datadog.collectEvents"
    value = true
  }
  set {
    name  = "datadog.rbac.create"
    value = true
  }
  set {
    name  = "datadog.logs.autoMultiLineDetection"
    value = false
  }
  set {
    name  = "clusterAgent.enabled"
    value = true
  }
  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = true
  }
  # KEDA Key bits: enable metrics provider but DON'T register the APIService
  set {
    name  = "clusterAgent.metricsProvider.registerAPIService"
    value = "false"
  }
  set {
    name  = "clusterAgent.metricsProvider.useDatadogMetrics"
    value = "true"
  }
  # Optional but recommended per KEDA docs
  set {
    name  = "clusterAgent.env[0].name"
    value = "DD_EXTERNAL_METRICS_PROVIDER_ENABLE_DATADOGMETRIC_AUTOGEN"
  }
  set {
    name  = "clusterAgent.env[0].value"
    value = "false"
  }
  # DD_REMOTE_CONFIGURATION_ENABLED
  set {
    name  = "remoteConfiguration.enabled"
    value = true
  }
  set {
    name  = "networkMonitoring.enabled"
    value = true
  }
  set {
    name  = "systemProbe.enableTCPQueueLength"
    value = true
  }
  set {
    name  = "systemProbe.enableOOMKill"
    value = true
  }
  set {
    name  = "datadog.orchestratorExplorer.enabled"
    value = true
  }
  set {
    name = "agents.image.tag"
    #value = "7.51.0"
    #value = "7.70.2-linux"
    value = "7.60.0"
  }
  # this is not required
  # set {
  #   name  = "datadog.dogstatsd.tags"
  #   value = "env:${var.environment} cloud_provider:${var.cloud_provider}"
  # }
  set {
    name  = "datadog.tags"
    value = "env:${var.environment} cloud_provider:${var.cloud_provider}"
  }
  # Disabled due to the agent throwing a
  # 'unable to read authentication token file: open /etc/datadog-agent/auth_token: no such file or directory'
  # error on start up
  # set {
  #   name  = "securityAgent.runtime.enabled"
  #   value = true
  # }
  # set {
  #  name  = "datadog.hostVolumeMountPropagation"
  #  value = "HostToContainer"
  # }
  set {
    name  = "datadog.apm.enabled"
    value = true
  }
  set {
    name  = "datadog.apm.socketEnabled"
    value = true
  }
  set {
    name  = "datadog.apm.portEnabled"
    value = true
  }
  set {
    name  = "datadog.apm.hostSocketPath"
    value = "/var/run/datadog/apm"
  }
  set {
    name  = "datadog.apm.socketPath"
    value = "/var/run/datadog/apm/apm.socket"
  }
  set {
    # https://github.com/DataDog/helm-charts/issues/975
    # this is required to get socketPath to mount!!!
    name  = "datadog.dogstatsd.useSocketVolume"
    value = false
  }
  set {
    name  = "datadog.dogstatsd.socketPath"
    value = "/var/run/datadog/dsd/dsd.socket"
  }
  set {
    name  = "datadog.processAgent.enabled"
    value = true
  }
  set {
    name  = "datadog.processAgent.processCollection"
    value = true
  }
  #  set {
  #    name  = "clusterAgent.admissionController.enabled"
  #    value = true
  #  }
  set {
    name  = "datadog.targetSystem"
    value = "linux"
  }
  set {
    name  = "clusterAgent.replicas"
    value = 2
  }

  # Tolerate Taint: # nvidia.com/gpu=present
  set {
    name  = "agents.tolerations[0].key"
    value = "nvidia.com/gpu"
  }
  set {
    name  = "agents.tolerations[0].value"
    value = "present"
  }
  set {
    name  = "agents.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "agents.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Tolerate Taint: # cloud.google.com/compute-class=dws-model-inference-a3-highgpu-2g-class
  set {
    name  = "agents.tolerations[1].key"
    value = "cloud.google.com/compute-class"
  }
  set {
    name  = "agents.tolerations[1].operator"
    value = "Exists"
  }
  set {
    name  = "agents.tolerations[1].effect"
    value = "NoSchedule"
  }

  # Tolerate Taint: # nvidia.com/gpu=present
  set {
    name  = "clusterAgent.tolerations[0].key"
    value = "nvidia.com/gpu"
  }
  set {
    name  = "clusterAgent.tolerations[0].value"
    value = "present"
  }
  set {
    name  = "clusterAgent.tolerations[0].operator"
    value = "Equal"
  }
  set {
    name  = "clusterAgent.tolerations[0].effect"
    value = "NoSchedule"
  }

  # Tolerate Taint: # cloud.google.com/compute-class=dws-model-inference-a3-highgpu-2g-class
  set {
    name  = "clusterAgent.tolerations[1].key"
    value = "cloud.google.com/compute-class"
  }
  set {
    name  = "clusterAgent.tolerations[1].operator"
    value = "Exists"
  }
  set {
    name  = "clusterAgent.tolerations[1].effect"
    value = "NoSchedule"
  }

  # https://docs.datadoghq.com/containers/guide/autodiscovery-management/?tab=containerizedagent
  set {
    name  = "clusterAgent.containerInclude"
    value = "kube_namespace:apps-.*"
  }
  set {
    name  = "datadog.containerInclude"
    value = "kube_namespace:apps-.*"
  }

  # Exclude kube-system namespace from container-level monitoring (metrics, logs, and autodiscovery)
  # This prevents the Datadog agent from scraping CoreDNS/kube-dns/node-cache pods
  # Note: Only "image:", "name:", and "kube_namespace:" prefixes are supported by the agent.
  # "image_name:" and "kube_container_name:" are IGNORED (verified in agent v7.60).
  # https://docs.datadoghq.com/containers/guide/container-discovery-management/?tab=helm#exclude-containers
  set {
    name  = "datadog.containerExcludeMetrics"
    value = "kube_namespace:kube-system"
  }
  set {
    name  = "datadog.containerExcludeLogs"
    value = "kube_namespace:kube-system"
  }
  set {
    name  = "datadog.containerExclude"
    value = "kube_namespace:kube-system"
  }

  timeout      = 3600 # 25 minutes
  force_update = true
  values = [
    yamlencode({
      datadog = {
        logs_enabled  = true
        apm_enabled   = true
        process_agent = { enabled = true }

        prometheus_scrape = {
          enabled = true
        }

        # Prevent autodiscovery of CoreDNS/kube-dns integration checks (scrape :9153/metrics)
        # https://docs.datadoghq.com/containers/guide/autodiscovery-management/?tab=containerizedagent#exclude-integration-templates
        ignoreAutoConfig = ["coredns", "kube_dns"]
      }

      agents = {
        containers = {
          agent = {
            env = [
              {
                name  = "DD_PROMETHEUS_SCRAPE_ENABLED"
                value = "true"
              },
              {
                name = "DD_PROMETHEUS_SCRAPE_CHECKS"
                value = jsonencode([
                  {
                    autodiscovery = {
                      # Only discover pods in apps-* namespaces — prevents scraping
                      # CoreDNS/kube-dns in kube-system which generates coredns_* custom metrics
                      kubernetes_annotations = {
                        include = {
                          "prometheus.io/scrape" = "true"
                        }
                      }
                      kubernetes_container_names = ["*"]
                    }
                    configurations = [
                      {
                        namespace = ".*"
                        metrics   = ["*"]
                      }
                    ]
                  }
                ])
              },
              # Explicitly set DD_IGNORE_AUTOCONF to prevent auto-discovery of CoreDNS/kube-dns checks
              {
                name  = "DD_IGNORE_AUTOCONF"
                value = "coredns kube_dns"
              }
            ]
          }
        }
      }

      # Create custom autodiscovery config (see below)
      confd = {
        "prometheus.yaml" = <<-EOT
          init_config:
          instances:
            - prometheus_url: http://%%host%%:8002/metrics
              namespace: vllm
              metrics:
                - "*"
        EOT
      }

      # Make sure the agent can reach the pod IP or use service discovery
      kubelet = {
        host = "host"
      }
    })
  ]
  lifecycle {
    # ignore_changes = [
    #   status
    # ]
  }
}

resource "kubernetes_namespace" "k8-cluster-default-namespaces" {
  count = length(var.create_namespaces)
  metadata {
    labels = {
      env = var.environment
    }
    name = var.create_namespaces[count.index]
  }
}

# Enable GKE Network Endpoint Group (NEG) controller on the cluster
# https://github.com/GoogleCloudPlatform/gke-autoneg-controller?tab=readme-ov-file
module "autoneg" {

  count                         = 0
  source                        = "github.com/GoogleCloudPlatform/gke-autoneg-controller//terraform/autoneg"
  project_id                    = var.project_id
  service_account_id            = "${var.cluster_name_short}-autoneg-sa"
  custom_role_add_random_suffix = true
  workload_identity = {
    namespace       = "autoneg-system"
    service_account = "${var.cluster_name_short}-autoneg-sa"
  }
}

# Based on https://faun.pub/setting-up-anthos-in-gke-for-demo-using-terraform-210ec227819a
# module "container-cluster-without-autopilot-asm" {
#
#   count                     = 0
#   source                    = "terraform-google-modules/kubernetes-engine/google//modules/asm"
#   version                   = "30.0.0"
#   project_id                = var.project_id
#   cluster_name              = var.cluster_name
#   cluster_location          = var.region
#   enable_cni                = true
#   enable_mesh_feature = true
#   #enable_vpc_sc             = true
#   enable_fleet_registration = false
#   #fleet_id                  = null # var.gke_hub_fleet_id
# }

# https://cloud.google.com/service-directory/docs/configuring-sd-for-gke
# Note - There are some manual steps required to make this work as of this writing (04-24-2023)

resource "kubernetes_manifest" "service-directory-registration-policy" {
  count      = length(var.create_namespaces)
  depends_on = [kubernetes_namespace.k8-cluster-default-namespaces]
  timeouts {
    create = "5m"
  }
  manifest = {
    apiVersion = "networking.gke.io/v1alpha1"
    kind       = "ServiceDirectoryRegistrationPolicy"
    metadata = {
      # Only the name "default" is allowed.
      name = "default"
      # The ServiceDirectoryRegistrationPolicy is a namespaced resource
      namespace = var.create_namespaces[count.index]
    }
    spec = {
      resources = [
        {
          # Kind specifies the types of Kubernetes resources that can be synced into Service Directory.
          kind = "Service"
          # Selector is a label selector for the resource types specified in Kind.
          selector = {
            matchLabels = {
              "sd-import" = "true"
            }
          }
          # annotationsToSync specifies the annotations that are matched and imported.
          # Any annotations that do not match this set of keys will not be imported into Service Directory.
          annotationsToSync = [
            "cloud.google.com/load-balancer-type"
          ]
        }
      ]
    }
  }
}

# Nvidia DCGM Exporter related configs
# Based on docs - https://docs.datadoghq.com/integrations/dcgm/?tab=kubernetes
resource "kubernetes_manifest" "role-binding-and-role-used-by-the-dcgm-pods-role" {
  count      = var.enable_nvidia_dcgm_exporter ? 1 : 0
  depends_on = [kubernetes_namespace.k8-cluster-default-namespaces]
  timeouts {
    create = "5m"
  }
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"
    metadata = {
      name      = "dcgm-exporter-read-datadog-cm"
      namespace = "kube-system"
    }
    rules = [
      {
        apiGroups     = [""]
        resources     = ["configmaps"]
        resourceNames = ["datadog-dcgm-exporter-configmap"]
        verbs         = ["get"]
      }
    ]
  }
}

resource "kubernetes_manifest" "role-binding-and-role-used-by-the-dcgm-pods-role-binding" {
  count = var.enable_nvidia_dcgm_exporter ? 1 : 0
  depends_on = [
    kubernetes_namespace.k8-cluster-default-namespaces,
    kubernetes_manifest.role-binding-and-role-used-by-the-dcgm-pods-role
  ]
  timeouts {
    create = "5m"
  }
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata = {
      name      = "dcgm-exporter-datadog"
      namespace = "kube-system"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "dcgm-datadog-dcgm-exporter"
        namespace = "kube-system"
      }
    ]
    roleRef = {
      kind     = "Role"
      name     = "dcgm-exporter-read-datadog-cm"
      apiGroup = "rbac.authorization.k8s.io"
    }
  }
}

resource "kubernetes_manifest" "role-binding-and-role-used-by-the-dcgm-pods-configmap" {
  count = var.enable_nvidia_dcgm_exporter ? 1 : 0
  depends_on = [
    kubernetes_namespace.k8-cluster-default-namespaces,
    kubernetes_manifest.role-binding-and-role-used-by-the-dcgm-pods-role,
    kubernetes_manifest.role-binding-and-role-used-by-the-dcgm-pods-role-binding
  ]
  timeouts {
    create = "5m"
  }
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "datadog-dcgm-exporter-configmap"
      namespace = "kube-system"
    }
    data = {
      metrics = <<-EOT
        # Copy the content from the Installation section.
        # Format
        # If line starts with a '#' it is considered a comment
        # DCGM FIELD                                                      ,Prometheus metric type ,help message

        # Clocks
        DCGM_FI_DEV_SM_CLOCK                                              ,gauge                  ,SM clock frequency (in MHz).
        DCGM_FI_DEV_MEM_CLOCK                                             ,gauge                  ,Memory clock frequency (in MHz).

        # Temperature
        DCGM_FI_DEV_MEMORY_TEMP                                           ,gauge                  ,Memory temperature (in C).
        DCGM_FI_DEV_GPU_TEMP                                              ,gauge                  ,GPU temperature (in C).

        # Power
        DCGM_FI_DEV_POWER_USAGE                                           ,gauge                  ,Power draw (in W).
        DCGM_FI_DEV_TOTAL_ENERGY_CONSUMPTION                              ,counter                ,Total energy consumption since boot (in mJ).

        # PCIE
        DCGM_FI_DEV_PCIE_REPLAY_COUNTER                                   ,counter                ,Total number of PCIe retries.

        # Utilization (the sample period varies depending on the product)
        DCGM_FI_DEV_GPU_UTIL                                              ,gauge                  ,GPU utilization (in %).
        DCGM_FI_DEV_MEM_COPY_UTIL                                         ,gauge                  ,Memory utilization (in %).
        DCGM_FI_DEV_ENC_UTIL                                              ,gauge                  ,Encoder utilization (in %).
        DCGM_FI_DEV_DEC_UTIL                                              ,gauge                  ,Decoder utilization (in %).

        # Errors and violations
        DCGM_FI_DEV_XID_ERRORS                                            ,gauge                  ,Value of the last XID error encountered.

        # Memory usage
        DCGM_FI_DEV_FB_FREE                                               ,gauge                  ,Framebuffer memory free (in MiB).
        DCGM_FI_DEV_FB_USED                                               ,gauge                  ,Framebuffer memory used (in MiB).

        # NVLink
        DCGM_FI_DEV_NVLINK_BANDWIDTH_TOTAL                                ,counter                ,Total number of NVLink bandwidth counters for all lanes.

        # VGPU License status
        DCGM_FI_DEV_VGPU_LICENSE_STATUS                                   ,gauge                  ,vGPU License status

        # Remapped rows
        DCGM_FI_DEV_UNCORRECTABLE_REMAPPED_ROWS                           ,counter                ,Number of remapped rows for uncorrectable errors
        DCGM_FI_DEV_CORRECTABLE_REMAPPED_ROWS                             ,counter                ,Number of remapped rows for correctable errors
        DCGM_FI_DEV_ROW_REMAP_FAILURE                                     ,gauge                  ,Whether remapping of rows has failed

        # DCP metrics
        DCGM_FI_PROF_PCIE_TX_BYTES                                        ,counter                ,The number of bytes of active pcie tx data including both header and payload.
        DCGM_FI_PROF_PCIE_RX_BYTES                                        ,counter                ,The number of bytes of active pcie rx data including both header and payload.
        DCGM_FI_PROF_GR_ENGINE_ACTIVE                                     ,gauge                  ,Ratio of time the graphics engine is active (in %).
        DCGM_FI_PROF_SM_ACTIVE                                            ,gauge                  ,The ratio of cycles an SM has at least 1 warp assigned (in %).
        DCGM_FI_PROF_SM_OCCUPANCY                                         ,gauge                  ,The ratio of number of warps resident on an SM (in %).
        DCGM_FI_PROF_PIPE_TENSOR_ACTIVE                                   ,gauge                  ,Ratio of cycles the tensor (HMMA) pipe is active (in %).
        DCGM_FI_PROF_DRAM_ACTIVE                                          ,gauge                  ,Ratio of cycles the device memory interface is active sending or receiving data (in %).
        DCGM_FI_PROF_PIPE_FP64_ACTIVE                                     ,gauge                  ,Ratio of cycles the fp64 pipes are active (in %).
        DCGM_FI_PROF_PIPE_FP32_ACTIVE                                     ,gauge                  ,Ratio of cycles the fp32 pipes are active (in %).
        DCGM_FI_PROF_PIPE_FP16_ACTIVE                                     ,gauge                  ,Ratio of cycles the fp16 pipes are active (in %).

        # Datadog additional recommended fields
        DCGM_FI_DEV_COUNT                                                 ,counter                ,Number of Devices on the node.
        DCGM_FI_DEV_FAN_SPEED                                             ,gauge                  ,Fan speed for the device in percent 0-100.
        DCGM_FI_DEV_SLOWDOWN_TEMP                                         ,gauge                  ,Slowdown temperature for the device.
        DCGM_FI_DEV_POWER_MGMT_LIMIT                                      ,gauge                  ,Current power limit for the device.
        DCGM_FI_DEV_PSTATE                                                ,gauge                  ,Performance state (P-State) 0-15. 0=highest
        DCGM_FI_DEV_FB_TOTAL                                              ,gauge                  ,
        DCGM_FI_DEV_FB_RESERVED                                           ,gauge                  ,
        DCGM_FI_DEV_FB_USED_PERCENT                                       ,gauge                  ,
        DCGM_FI_DEV_CLOCK_THROTTLE_REASONS                                ,gauge                  ,Current clock throttle reasons (bitmask of DCGM_CLOCKS_THROTTLE_REASON_*)

        DCGM_FI_PROCESS_NAME                                              ,label                  ,The Process Name.
        DCGM_FI_CUDA_DRIVER_VERSION                                       ,label                  ,
        DCGM_FI_DEV_NAME                                                  ,label                  ,
        DCGM_FI_DEV_MINOR_NUMBER                                          ,label                  ,
        DCGM_FI_DRIVER_VERSION                                            ,label                  ,
        DCGM_FI_DEV_BRAND                                                 ,label                  ,
        DCGM_FI_DEV_SERIAL                                                ,label
      EOT
    }
  }
}

# https://github.com/NVIDIA/dcgm-exporter/blob/main/deployment/values.yaml
# https://github.com/NVIDIA/gpu-monitoring-tools/issues/96
# Requires
#       affinity:
#        nodeAffinity:
#          requiredDuringSchedulingIgnoredDuringExecution:
#            nodeSelectorTerms:
#            - matchExpressions:
#              - key: cloud.google.com/gke-accelerator
#                operator: Exists
resource "helm_release" "dcgm-exporter" {
  count            = var.enable_nvidia_dcgm_exporter ? 1 : 0
  name             = "dcgm-exporter"
  namespace        = "kube-system"
  create_namespace = true
  repository       = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  # pin it to avoid auto-upgrade breaking changes
  # Later versions suffer this crash
  # https://github.com/NVIDIA/dcgm-exporter/issues/242
  version      = "3.1.2"
  chart        = "dcgm-exporter"
  force_update = true
  values = [
    <<VALUES
# Exposing more metrics than the default for additional monitoring - this requires the use of a dedicated ConfigMap for which the Kubernetes ServiceAccount used by the exporter has access thanks to step 1.
# Ref: https://github.com/NVIDIA/dcgm-exporter/blob/e55ec750def325f9f1fdbd0a6f98c932672002e4/deployment/values.yaml#L38

arguments: ["-m", "kube-system:datadog-dcgm-exporter-configmap"]
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: cloud.google.com/gke-accelerator
          operator: Exists

# Datadog Autodiscovery V2 annotations
podAnnotations:
  ad.datadoghq.com/exporter.checks: |-
    {
      "dcgm": {
        "instances": [
          {
            "openmetrics_endpoint": "http://%%host%%:9400/metrics"
          }
        ]
      }
    }
# Optional - Disabling the ServiceMonitor which requires Prometheus CRD - can be re-enabled if Prometheus CRDs are installed in your cluster
serviceMonitor:
  enabled: false
VALUES
  ]
}
