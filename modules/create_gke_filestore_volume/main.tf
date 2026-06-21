# Based on docs -
# https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#provision-static
# https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#authentication
#
# Local NFS mounting instructions:
# https://cloud.google.com/filestore/docs/transfer-data-from-gcs
#
# GCS to NFS transfer instructions:
# https://cloud.google.com/filestore/docs/transfer-data-from-gcs
#

locals {
  persistent_volume_storage_class_name = "gcs-persistent-volume-storage-class"
  filestore_instance_service_tier      = var.filestore_instance_service_tier
}

resource "google_filestore_instance" "filestore_instance_inference_service" {
  name     = var.filestore_instance_name
  location = var.region
  tier     = local.filestore_instance_service_tier
  project  = var.project_id

  file_shares {
    capacity_gb = var.persistent_volume_capacity
    name        = "llm_inf_fshare"
    nfs_export_options {
      ip_ranges = [var.nfs_export_ip_cidr_range]
      access_mode = "READ_WRITE"
      squash_mode = "NO_ROOT_SQUASH"
    }
  }
  networks {
    network      = var.vpc_name
    modes = ["MODE_IPV4"]
    connect_mode = "DIRECT_PEERING"
  }
  dynamic "performance_config" {
    for_each = [1]
    content {
      fixed_iops {
        max_iops = 34000
      }
    }
  }
}

# Create a PersistentVolume
resource "kubernetes_persistent_volume" "persistent_volume" {
  metadata {
    name = var.persistent_volume_name
  }

  spec {
    access_modes = ["ReadWriteMany"]
    capacity = {
      storage = var.persistent_volume_capacity
    }
    persistent_volume_reclaim_policy = var.persistent_volume_reclaim_policy
    volume_mode                      = "Filesystem"
    claim_ref {
      name      = var.persistent_volume_claim_name
      namespace = var.persistent_volume_claim_namespace
    }
    persistent_volume_source {
      csi {
        driver        = "filestore.csi.storage.gke.io"
        volume_handle = "modeInstance/${var.filestore_instance_location}/${var.filestore_instance_name}/${var.filestore_share_name}"
        read_only     = var.read_only
        volume_attributes = {
          ip     = var.filestore_instance_ip
          volume = var.filestore_share_name
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "persistent_volume_claim" {

  depends_on = [kubernetes_persistent_volume.persistent_volume]
  wait_until_bound = false
  metadata {
    name      = var.persistent_volume_claim_name
    namespace = var.persistent_volume_claim_namespace
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = var.persistent_volume_capacity
      }
    }
    volume_name        = var.persistent_volume_name
    storage_class_name = local.persistent_volume_storage_class_name
  }
}


