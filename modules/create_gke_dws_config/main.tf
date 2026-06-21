terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}


# Install kueue
locals {
  kueue_raw_docs  = [for doc in split("\n---\n", file("${path.module}/kueue-manifests.yaml")) : trimspace(doc)]
  kueue_manifests = { for doc in local.kueue_raw_docs : sha256(doc) => doc if doc != "" }
}

# kueue install manifests. Uses kubectl_manifest (yaml_body kept as an opaque
# string) instead of kubernetes_manifest so that GKE/Kubernetes API schema
# changes (e.g. the k8s 1.34 addition of podCertificate / env.fileKeyRef) don't
# break the plan with "Failed to update proposed state from prior state".
resource "kubectl_manifest" "kueue" {
  for_each         = local.kueue_manifests
  yaml_body        = each.value
  server_side_apply = true
  force_conflicts  = true
}

resource "kubernetes_manifest" "resource_flavor" {
  depends_on = [
    kubectl_manifest.kueue,
  ]
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "ResourceFlavor"
    metadata = {
      name = var.resource_flavor_name
    }
  }
}

resource "kubernetes_manifest" "admission_check" {
  depends_on = [
    kubectl_manifest.kueue,
    kubernetes_manifest.resource_flavor,
  ]
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "AdmissionCheck"
    metadata = {
      name = var.admission_check_name
    }
    spec = {
      controllerName    = "kueue.x-k8s.io/provisioning-request"
      retryDelayMinutes = 15
      parameters = {
        apiGroup = "kueue.x-k8s.io"
        kind     = "ProvisioningRequestConfig"
        name     = var.provisioning_config_name
      }
    }
  }
}

resource "kubernetes_manifest" "provisioning_request_config" {
  depends_on = [
    kubectl_manifest.kueue,
    kubernetes_manifest.admission_check
  ]
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "ProvisioningRequestConfig"
    metadata = {
      name = var.provisioning_config_name
    }
    spec = {
      provisioningClassName = var.provisioning_class_name
      managedResources      = var.managed_resources
      retryStrategy = {
        backoffBaseSeconds = 60
        backoffLimitCount  = 30
        backoffMaxSeconds  = 1800
      }
    }
  }
}

resource "kubernetes_manifest" "cluster_queue" {
  depends_on = [
    kubectl_manifest.kueue,
    kubernetes_manifest.provisioning_request_config
  ]
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "ClusterQueue"
    metadata = {
      name = var.cluster_queue_name
    }
    spec = {
      namespaceSelector = {}
      resourceGroups = [
        {
          coveredResources = var.covered_resources
          flavors = [
            {
              name = var.resource_flavor_name
              resources = [for resource in var.resources : {
                name         = resource.name
                nominalQuota = resource.quota
              }]
            }
          ]
        }
      ]
      admissionChecks = [var.admission_check_name]
    }
  }
}

resource "kubernetes_manifest" "local_queue" {
  depends_on = [
    kubectl_manifest.kueue,
    kubernetes_manifest.cluster_queue
  ]
  manifest = {
    apiVersion = "kueue.x-k8s.io/v1beta1"
    kind       = "LocalQueue"
    metadata = {
      namespace = var.namespace
      name      = var.local_queue_name
    }
    spec = {
      clusterQueue = var.cluster_queue_name
    }
  }
}
