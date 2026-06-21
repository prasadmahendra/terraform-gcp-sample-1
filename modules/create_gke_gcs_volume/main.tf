# Based on docs -
# https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#provision-static
# https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/cloud-storage-fuse-csi-driver#authentication

locals {
  persistent_volume_storage_class_name = "gcs-persistent-volume-storage-class"
}

# Create a PersistentVolume
resource "kubernetes_persistent_volume" "persistent_volume" {
  metadata {
    name = var.persistent_volume_name
  }

  spec {
    access_modes = ["ReadWriteMany"]
    capacity     = {
      storage = var.persistent_volume_capacity
    }
    persistent_volume_reclaim_policy = var.persistent_volume_reclaim_policy
    # storage_class_name fields on PV and PVC manifests should match.
    # The storageClassName does not need to refer to an existing StorageClass object.
    # To bind the claim to a volume, you can use any name you want but it cannot be empty.
    storage_class_name = local.persistent_volume_storage_class_name
    claim_ref {
      name      = var.persistent_volume_claim_name
      namespace = var.persistent_volume_claim_namespace
    }
    mount_options = concat([
      "implicit-dirs"
    ], var.mount_options)
    persistent_volume_source {
      csi {
        driver        = "gcsfuse.csi.storage.gke.io"
        volume_handle = var.bucket_name
        read_only     = var.read_only
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "persistent_volume_claim" {

  depends_on       = [kubernetes_persistent_volume.persistent_volume]
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


