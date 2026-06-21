terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  # GPU machine types (e.g. a3-highgpu-1g) require an explicit gpu block for node
  # pool auto-creation, otherwise NAP provisions nodes that don't advertise
  # nvidia.com/gpu and GPU Pods stay Pending. Omitted for non-GPU machine types.
  gpu_block = var.gpu_type != null ? {
    gpu = {
      type  = var.gpu_type
      count = var.gpu_count
    }
  } : {}

  spot_instance_priority = [
    {
      machineType           = var.machine_type
      spot                  = true
      maxRunDurationSeconds = null
      flexStart             = null
    },
    merge({
      machineType = var.machine_type
      spot        = false
      storage = {
        bootDiskSize = var.boot_disk_size # eg: 1024 for 1TB
        localSSDCount = var.local_ssd_count # Ephemeral local SSD disks (per node) 16
      }
      maxRunDurationSeconds = var.max_run_duration_seconds
      flexStart = {
        enabled = true
        nodeRecycling = {
          leadTimeSeconds = var.node_recycling_lead_time_seconds
        }
      }
    }, local.gpu_block)
  ]

  spot_instance_is_not_a_priority = [
    merge({
      machineType           = var.machine_type
      maxRunDurationSeconds = var.max_run_duration_seconds
      spot                  = false
      storage = {
        bootDiskSize = var.boot_disk_size # eg: 1024 for 1TB
        localSSDCount = var.local_ssd_count # Ephemeral local SSD disks (per node) 16
      }
      flexStart = {
        enabled = true
        nodeRecycling = {
          leadTimeSeconds = var.node_recycling_lead_time_seconds
        }
      }
    }, local.gpu_block)
  ]
}

# https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler
# Custom compute class docs -- https://cloud.google.com/kubernetes-engine/docs/concepts/about-custom-compute-classes
resource "kubernetes_manifest" "kubernetes_manifest_ingress_backend_config" {
  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "ComputeClass"
    metadata = {
      name = var.compute_class_name
    }
    spec = {
      nodePoolConfig = {
        serviceAccount = var.service_account_email
      }
      priorities = local.spot_instance_is_not_a_priority
      nodePoolAutoCreation = {
        enabled = true
      }
    }
  }
}
