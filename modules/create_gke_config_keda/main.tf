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


data "google_secret_manager_secret_version" "datadog_api_key" {
  secret  = "datadog_api_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "datadog_app_key" {
  secret  = "datadog_app_key"
  project = var.project_id
}

data "google_secret_manager_secret_version" "temporal-api-key" {
  secret  = "temporal-api-key"
  project = var.project_id
}

locals {
  keda_repository         = "https://kedacore.github.io/charts"
  keda_version            = "2.17.2" # this will have to be upgraded if K8s is upgraded past v1.34
  keda_http_addon_version = "0.10.0"
  gke_namespaces          = concat(var.gke_namespaces, [])
}

# Install the KEDA chart
resource "helm_release" "keda" {
  name             = "keda"
  chart            = "keda"
  namespace        = "keda"
  repository       = local.keda_repository
  version          = local.keda_version
  create_namespace = true
  # Required if your GKE cluster’s cluster_dns_domain is not the default cluster.local.
  # All options listed here: https://artifacthub.io/packages/helm/kedacore/keda
  set {
    name = "clusterDomain"
    # When you created the GKE cluster with cluster_dns_domain and CLOUD_DNS,
    # Google set the cluster domain to svc.gke-default.dev.spiffy.ai. So the "svc." prefix is needed.
    value = var.gke_dns_cluster_domain
  }
  set {
    name  = "operator.metricsServerAddress"
    value = "keda-operator.keda.svc:9666"
  }
  set {
    name  = "metricsServer.dnsPolicy"
    value = "ClusterFirst" # ClusterFirst is default
  }
  set {
    name  = "metricsServer.useHostNetwork"
    value = "false" # default is false
  }
  set {
    name  = "prometheus.metricServer.port"
    value = "8080" # default is 8080, but this avoids conflict with GKE add-on
  }
  set {
    name  = "clusterName"
    value = var.gke_cluster_name
  }
}

resource "google_project_iam_member" "keda_operator_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "principal://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/keda/sa/keda-operator"
}

# Install the KEDA chart
resource "helm_release" "keda-add-ons-http" {
  count            = 0 # disabled for now since we don't use it yet
  name             = "http-add-on"
  repository       = local.keda_repository
  version          = local.keda_http_addon_version
  chart            = "keda-add-ons-http"
  namespace        = "keda"
  create_namespace = true

  # --set interceptor.responseHeaderTimeout=120s
  set {
    name  = "interceptor.responseHeaderTimeout"
    value = "120s"
  }

  # Make sure KEDA is up first
  depends_on = [helm_release.keda]
}

# ---- KEDA TriggerAuthentication using GCP Workload Identity ----
resource "kubernetes_manifest" "keda_trigger_auth_gcp" {
  count = length(local.gke_namespaces)
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "gcp-wi-auth"
      namespace = local.gke_namespaces[count.index]
    }
    spec = {
      podIdentity = {
        provider = "gcp"
      }
    }
  }

  # Make sure KEDA is up first
  depends_on = [helm_release.keda]
}

# Install the DD secrets in all namespaces for REST API access
resource "kubernetes_manifest" "datadog_secrets" {
  count = length(local.gke_namespaces)
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "datadog-secrets"
      "namespace" = local.gke_namespaces[count.index]
    }
    "type" = "Opaque"
    "data" = {
      "apiKey"      = base64encode(data.google_secret_manager_secret_version.datadog_api_key.secret_data)
      "appKey"      = base64encode(data.google_secret_manager_secret_version.datadog_app_key.secret_data)
      "datadogSite" = base64encode(var.datadog_site)
    }
  }

  # Make sure KEDA is up first
  depends_on = [helm_release.keda]
}

resource "kubernetes_manifest" "temporal_secret" {
  count = length(local.gke_namespaces)
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "temporal-secrets"
      "namespace" = local.gke_namespaces[count.index]
    }
    "type" : "Opaque"
    "data" = {
      "apiKey" = base64encode(data.google_secret_manager_secret_version.temporal-api-key.secret_data)
    }
  }

  # Make sure KEDA is up first
  depends_on = [helm_release.keda]
}

# Install the TriggerAuthentication and Datadog secrets in the specified namespace for Datadog access via REST API
resource "kubernetes_manifest" "keda_trigger_auth_datadog" {
  count = length(local.gke_namespaces)
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "keda-trigger-auth-datadog-secret"
      namespace = local.gke_namespaces[count.index]
    }
    spec = {
      secretTargetRef = [
        {
          parameter = "apiKey"
          name      = "datadog-secrets"
          key       = "apiKey"
        },
        {
          parameter = "appKey"
          name      = "datadog-secrets"
          key       = "appKey"
        },
        {
          parameter = "datadogSite"
          name      = "datadog-secrets"
          key       = "datadogSite"
        }
      ]
    }
  }

  # Make sure KEDA is up first
  depends_on = [kubernetes_manifest.datadog_secrets]
}

# Install the TriggerAuthentication and Temporal secrets in the specified namespace for Temporal access via KEDA
resource "kubernetes_manifest" "keda_trigger_auth_temporal" {
  count = length(local.gke_namespaces)
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "keda-trigger-auth-temporal"
      namespace = local.gke_namespaces[count.index]
    }
    spec = {
      secretTargetRef = [
        {
          parameter = "apiKey"
          name      = "temporal-secrets"
          key       = "apiKey"
        }
      ]
    }
  }

  # Make sure KEDA is up first
  depends_on = [kubernetes_manifest.temporal_secret]
}

data "kubernetes_secret" "datadog_cluster_agent_token" {
  metadata {
    name      = "datadog-agent-cluster-agent"
    namespace = var.datadog_cluster_agent_namespace
  }
}

# DD cluster agent secrets config
resource "kubernetes_manifest" "datadog_cluster_agent_secrets" {
  count = length(local.gke_namespaces)
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "datadog-cluster-agent-config"
      "namespace" = local.gke_namespaces[count.index]
    }
    "type" = "Opaque"
    "data" = {
      "datadogNamespace"         = base64encode(var.datadog_cluster_agent_namespace)                              # Required: base64 encoded value of the namespace where the Datadog Cluster Agent is deployed
      "datadogMetricsService"    = base64encode(var.datadog_cluster_agent_service)                                # Required: base64 encoded value of the Cluster Agent metrics server service
      "unsafeSsl"                = base64encode(var.datadog_cluster_agent_unsafe_ssl)                             # Optional
      "authMode"                 = base64encode("bearer")                                                         # Required: base64 encoded value of the authentication mode (in this case, bearer)
      "datadogClusterAgentToken" = base64encode(data.kubernetes_secret.datadog_cluster_agent_token.data["token"]) # Required: base64 encoded value of the token used to authenticate with the Datadog Cluster Agent
    }
  }

  # Make sure KEDA is up first
  depends_on = [helm_release.keda]
}

# Install the TriggerAuthentication and Datadog secrets in the specified namespace for Datadog access via Cluster Agent
resource "kubernetes_manifest" "keda_trigger_auth_datadog_cluster_agent" {
  count = length(local.gke_namespaces)
  manifest = {
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "keda-trigger-auth-datadog-cluster-agent"
      namespace = local.gke_namespaces[count.index]
    }
    spec = {
      secretTargetRef = [
        {
          parameter = "token"
          name      = "datadog-cluster-agent-config"
          key       = "datadogClusterAgentToken"
        },
        {
          parameter = "datadogNamespace"
          name      = "datadog-cluster-agent-config"
          key       = "datadogNamespace"
        },
        {
          parameter = "unsafeSsl"
          name      = "datadog-cluster-agent-config"
          key       = "unsafeSsl"
        },
        {
          parameter = "authMode"
          name      = "datadog-cluster-agent-config"
          key       = "authMode"
        },
        {
          parameter = "datadogMetricsService"
          name      = "datadog-cluster-agent-config"
          key       = "datadogMetricsService"
        }
      ]
    }
  }

  # Make sure KEDA is up first
  depends_on = [kubernetes_manifest.datadog_secrets]
}
