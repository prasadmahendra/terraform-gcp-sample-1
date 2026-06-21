# Important for GPUs on autopilot:
# https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-gpus

locals {
  cluster_autoscale_resource_limits = [
    {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 2500
    },
    {
      resource_type = "memory"
      minimum       = 1
      maximum       = 25000
    },
    {
      resource_type = "nvidia-l4"
      minimum       = 1
      maximum       = 64
    },
    {
      resource_type = "nvidia-a100-80gb"
      minimum       = 1
      maximum       = 64
    },
    {
      resource_type = "nvidia-h100-80gb"
      minimum       = 1
      maximum       = 64
    }
  ]
}

resource "google_container_cluster" "container-cluster" {

  # to get around "remove_default_node_pool": conflicts with enable_autopilot"
  name                      = var.cluster_name
  project                   = var.project_id
  location                  = var.region
  network                   = var.vpc_name
  subnetwork                = var.subnet.name
  enable_autopilot          = null
  networking_mode           = "VPC_NATIVE"
  deletion_protection       = false
  min_master_version        = "1.33.8-gke.1026000" # "1.29.4-gke.1043002"
  default_max_pods_per_node = 110
  release_channel {
    channel = var.release_channel
  }
  resource_labels = {
    env     = var.environment
    team    = var.team
    mesh_id = "proj-${var.project_number}"
  }
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_ENTERPRISE"
  }
  #  private_cluster_config {
  #    enable_private_nodes = var.enable_private_nodes
  #  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = var.remove_default_node_pool
  initial_node_count       = 1
  node_locations           = var.node_locations

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  cluster_autoscaling {
    enabled             = var.cluster_autoscaling_enabled
    autoscaling_profile = var.cluster_autoscaling_profile
    dynamic "auto_provisioning_defaults" {
      for_each = var.auto_provisioning_defaults_enabled ? [1] : []
      content {
        service_account = var.autopilot_nodes_service_account_email
        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform",
          "https://www.googleapis.com/auth/logging.write",
          "https://www.googleapis.com/auth/monitoring",
        ]
      }
    }
    # auto_provisioning_defaults {
    #   service_account = var.autopilot_nodes_service_account_email
    #   oauth_scopes = [
    #     "https://www.googleapis.com/auth/cloud-platform",
    #     "https://www.googleapis.com/auth/logging.write",
    #     "https://www.googleapis.com/auth/monitoring",
    #   ]
    # }
    dynamic "resource_limits" {
      for_each = var.cluster_autoscaling_enabled ? local.cluster_autoscale_resource_limits : []
      content {
        resource_type = resource_limits.value.resource_type
        minimum       = resource_limits.value.minimum
        maximum       = resource_limits.value.maximum
      }
    }
  }
  mesh_certificates {
    enable_certificates = true
  }
  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    dns_cache_config {
      enabled = true
    }
  }
  dns_config {
    cluster_dns        = "CLOUD_DNS"
    cluster_dns_scope  = "VPC_SCOPE"
    cluster_dns_domain = var.dns_config_services_domain
  }
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      # "APISERVER", -- too noisy in DD
      # "SCHEDULER", -- too noisy in DD
      # "CONTROLLER_MANAGER", -- too noisy in DD
      "WORKLOADS"
    ]
  }
  maintenance_policy {
    recurring_window {
      end_time   = "2024-07-27T11:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"
      start_time = "2024-07-27T05:00:00Z"
    }
  }
  notification_config {
    pubsub {
      enabled = true
      topic   = var.notification_config_topic
    }
  }
  secret_manager_config {
    enabled = true
  }
  lifecycle {
    ignore_changes = [
      min_master_version,
      fleet,
      cluster_autoscaling[0].auto_provisioning_defaults
    ]
  }
}

resource "google_container_node_pool" "container-cluster-node-pool" {

  count          = length(var.node_pools)
  provider       = google-beta
  project        = var.project_id
  location       = var.region
  name           = var.node_pools[count.index].name
  cluster        = google_container_cluster.container-cluster.name
  node_count = var.node_pools[count.index].node_count
  autoscaling {
    location_policy      = var.node_pools[count.index].autoscaling.location_policy
    min_node_count       = var.node_pools[count.index].autoscaling.min_node_count
    max_node_count       = var.node_pools[count.index].autoscaling.max_node_count
    total_min_node_count = var.node_pools[count.index].autoscaling.total_min_node_count
    total_max_node_count = var.node_pools[count.index].autoscaling.total_max_node_count
  }

  network_config {
    enable_private_nodes = var.enable_private_nodes
  }
  management {
    auto_repair  = var.node_pools[count.index].management.auto_repair
    auto_upgrade = var.node_pools[count.index].management.auto_upgrade
  }
  upgrade_settings {
    max_surge       = var.node_pools[count.index].upgrade_settings.max_surge
    max_unavailable = var.node_pools[count.index].upgrade_settings.max_unavailable
    strategy        = var.node_pools[count.index].upgrade_settings.strategy
  }
  dynamic "queued_provisioning" {
    # setting this to "false" even though that's the default forces terraform to replace
    # the node pool. This is because the "queued_provisioning" field is not updatable
    for_each = var.node_pools[count.index].queued_provisioning.enabled ? [1] : []
    content {
      enabled = var.node_pools[count.index].queued_provisioning.enabled
    }
  }
  node_config {

    image_type   = "COS_CONTAINERD"
    preemptible  = var.node_pools[count.index].preemptible
    machine_type = var.node_pools[count.index].machine_type
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = var.node_pools[count.index].service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    metadata = {
      "disable-legacy-endpoints" = "true"
    }
    workload_metadata_config {
      # gke-metadata-server-enabled node-affinity is sought by autoneg so this is required
      mode = "GKE_METADATA"
    }
    labels = {
      env  = var.environment
      team = var.team
    }
    gcfs_config {
      enabled = true
    }
    gvnic {
      enabled = var.node_pools[count.index].gvnic.enabled
    }
    flex_start       = var.node_pools[count.index].flex_start.enabled ? true : false
    max_run_duration = var.node_pools[count.index].max_run_duration.enabled == true ? var.node_pools[count.index].max_run_duration.duration : null
    dynamic "guest_accelerator" {
      for_each = var.node_pools[count.index].guest_accelerator
      content {
        type  = guest_accelerator.value.type
        count = guest_accelerator.value.count
        # MIG partition size (e.g. "3g.40gb"); null on whole-GPU pools.
        gpu_partition_size = guest_accelerator.value.gpu_partition_size
        # Versions:
        # https://cloud.google.com/container-optimized-os/docs/release-notes
        # https://cloud.google.com/kubernetes-engine/docs/how-to/gpus.md
        # https://cloud.google.com/kubernetes-engine/docs/release-notes#current_versions
        # manul installations:
        # https://cloud.google.com/container-optimized-os/docs/how-to/run-gpus#install-driver
        # To check on installed drivers
        #   cd /home/kubernetes/bin/nvidia/bin
        #   ./nvidia-smi
        gpu_driver_installation_config {
          # gpu_driver_version = "DEFAULT"
          gpu_driver_version = "LATEST"
        }
      }
    }
    shielded_instance_config {
      enable_integrity_monitoring = true
      enable_secure_boot          = false
    }
    dynamic "reservation_affinity" {
      # Queued_provisioning requires reservation affinity to be set to none therefore
      # We are setting consume_reservation_type to NO_RESERVATION
      for_each = var.node_pools[count.index].flex_start.enabled == true || var.node_pools[count.index].queued_provisioning.enabled == true ? [1] : []
      content {
        consume_reservation_type = "NO_RESERVATION"
      }
    }
    dynamic "reservation_affinity" {
      for_each = var.node_pools[count.index].flex_start.enabled == false && var.node_pools[count.index].queued_provisioning.enabled == false && var.node_pools[count.index].reservation_affinity.enabled == true ? [1] : []
      content {
        consume_reservation_type = var.node_pools[count.index].reservation_affinity.consume_reservation_type
        key                      = var.node_pools[count.index].reservation_affinity.key
        values                   = var.node_pools[count.index].reservation_affinity.values
      }
    }
    disk_size_gb = var.node_pools[count.index].disk_size
  }

  # ignore changes to node_config[..].ephemeral_storage_local_ssd_config
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      node_config[0].ephemeral_storage_local_ssd_config,
      # To get around this error - QueuedProvisioning node pool feature supports only SHORT_LIVED upgrade strategy and it cannot be changed.
      # on DWS pools
      upgrade_settings[0].strategy
    ]
  }
}
