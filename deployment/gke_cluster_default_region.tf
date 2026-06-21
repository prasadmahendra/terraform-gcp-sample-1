moved {
  from = module.container-cluster-gpus-default
  to   = module.container-cluster-default
}

locals {
  gke_default_cluster_domain_dns   = "gke-default.${var.environment}.${var.root_domain}"
  datadog_cluster_agent_unsafe_ssl = "true"
}

# GPU computing GKE cluster
module "container-cluster-default" {

  count = var.gke_default_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  depends_on = [
    google_compute_router_nat.nat
  ]
  environment                = var.environment
  source                     = "../modules/create_gke"
  cluster_name               = "gke-default"
  cluster_name_short         = "gke-default"
  dns_config_services_domain = local.gke_default_cluster_domain_dns
  project_id                 = google_project.deployment-project.project_id
  project_number             = google_project.deployment-project.number
  region                     = var.region_default
  node_locations             = var.compute_zones_gpus_default_region
  release_channel            = "REGULAR"
  subnet = {
    name            = google_compute_subnetwork.deployment-subnet-app.name
    ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
    ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
  }
  vpc_name                 = google_compute_network.vpc-deployment.name
  remove_default_node_pool = true
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#autoscaling_profile
  cluster_autoscaling_profile           = "OPTIMIZE_UTILIZATION"
  cluster_autoscaling_enabled           = true
  notification_config_topic             = google_pubsub_topic.gke-cluster-notifications.id
  autopilot_nodes_service_account_email = google_service_account.gke_node_pool_service_account.email
  auto_provisioning_defaults_enabled    = true

  # GPU machine types:
  # https://cloud.google.com/compute/docs/gpus
  # Note - GPUs aren't available in all zones (must restrict cluster-zone to get desired results!)
  # https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
  enable_private_nodes = true
  node_pools = var.environment == "prod" ? [
    # c2-standard-8
    {
      name         = "gke-default-c2-standard-8-pool"
      machine_type = "c2-standard-8"
      node_count   = null
      disk_size    = 100
      autoscaling = {
        location_policy      = "BALANCED"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 1
        total_max_node_count = 40
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator     = []
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-8g
    {
      name         = "gke-default-a3-highgpu-8g-pool"
      machine_type = "a3-highgpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = 0
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-h100-80gb"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # g2-standard-96 (required to run the 7b models)
    {
      name         = "gke-default-g2-standard-96-pool"
      machine_type = "g2-standard-96"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = 0
        total_min_node_count = 0
        total_max_node_count = 1
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-l4"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # a2-highgpu-8g
    {
      name         = "gke-default-a2-highgpu-8g-pool"
      machine_type = "a2-highgpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = 0
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-tesla-a100"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # a2-ultragpu-8g
    {
      name         = "gke-default-a2-ultragpu-8g-pool"
      machine_type = "a2-ultragpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = 0
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-a100-80gb"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # a2-ultragpu-2g
    {
      name         = "gke-default-a2-ultragpu-2g-pool"
      machine_type = "a2-ultragpu-2g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 1
        total_max_node_count = 4
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-a100-80gb"
          count = 2
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        # NOTE(maintenance-window): change back to SPECIFIC_RESERVATION = "reservation-2a10080g-3yr-07-2024-${var.environment}"
        # Temporarily set to ANY_RESERVATION to match current TF state and avoid forced node pool replacement.
        enabled                  = true
        consume_reservation_type = "ANY_RESERVATION"
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # g2-standard-48 with L4 GPUs
    {
      name         = "gke-default-g2-standard-48-pool"
      machine_type = "g2-standard-48"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 2
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-l4"
          count = 4
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-8g-calmode-pool
    {
      name         = "a3-highgpu-8g-calmode-pool"
      machine_type = "a3-highgpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        # Cost optimization (2026-04): the reservation this pool was pinned to
        # (bfcm-surge-a3-highgpu-8g-2025-1-us-central1-c-3) no longer exists
        # (confirmed via `gcloud compute reservations describe` -> 404).
        # Park the pool at 0 nodes until a new calendar block is procured.
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-h100-80gb"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        # NOTE(maintenance-window): set enabled = false once the pool has been
        # properly replaced. Temporarily keeping state-matching values to avoid
        # forced replacement when applying unrelated resources.
        # Reservation (bfcm-surge-a3-highgpu-8g-2025-1-us-central1-c-3) is
        # expired/deleted but TF state still has SPECIFIC_RESERVATION recorded.
        enabled                  = true
        consume_reservation_type = "SPECIFIC_RESERVATION"
        key                      = "compute.googleapis.com/reservation-name"
        values                   = ["bfcm-surge-a3-highgpu-8g-2025-1-us-central1-c-3"]
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled = false
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-8g-flex-pool
    {
      name         = "a3-highgpu-8g-flex-pool"
      machine_type = "a3-highgpu-8g"
      node_count   = 0
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-h100-80gb"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = true
      }
      max_run_duration = {
        enabled = true # Required for flex start
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-2g-flex-pool
    {
      name         = "a3-highgpu-2g-flex-pool"
      machine_type = "a3-highgpu-2g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 4
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-h100-80gb"
          count = 2
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = true
      }
      max_run_duration = {
        enabled = true # Required for flex start
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-1g-mig-pool
    # Single H100 (a3-highgpu-1g) sliced via MIG into 2x 3g.40gb instances so two
    # independent model Pods can share ONE physical GPU (~40GB + 3/7 SMs each).
    # The node advertises nvidia.com/gpu: 2; each Pod requests nvidia.com/gpu: 1.
    # autoscaling capped at 1 node => at most one physical H100 for this pool.
    # Flex-start (DWS) is how this repo reliably obtains H100 capacity.
    {
      name         = "gke-default-a3-highgpu-1g-mig-pool"
      machine_type = "a3-highgpu-1g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 1
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type               = "nvidia-h100-80gb"
          count              = 1
          gpu_partition_size = "3g.40gb"
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = true
      }
      max_run_duration = {
        enabled = true # Required for flex start
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-2g-pool
    {
      name         = "a3-highgpu-2g-pool"
      machine_type = "a3-highgpu-2g"
      node_count   = 0
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-h100-80gb"
          count = 2
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled = true # Required for flex start
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # g4-standard-384-flex-pool
    {
      name         = "g4-standard-384-flex-pool"
      machine_type = "g4-standard-384"
      node_count   = 0
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-rtx-pro-6000"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = true
      }
      max_run_duration = {
        enabled = true # Required for flex start
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a3-ultragpu-8g-flex-pool
    # {
    #   name         = "a3-ultragpu-8g-flex-pool"
    #   machine_type = "a3-ultragpu-8g"
    #   node_count = 1
    #   autoscaling = {
    #     location_policy      = "ANY"
    #     min_node_count       = null
    #     max_node_count       = null
    #     total_min_node_count = 1
    #     total_max_node_count = 1
    #   }
    #   subnet = {
    #     name            = google_compute_subnetwork.deployment-subnet-app.name
    #     ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
    #     ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
    #   }
    #   vpc_id                = google_compute_network.vpc-deployment.id
    #   preemptible           = false
    #   service_account_email = google_service_account.gke_node_pool_service_account.email
    #   guest_accelerator = [
    #     {
    #       type  = "nvidia-h200-141gb"
    #       count = 8
    #     }
    #   ]
    #   gvnic = {
    #     enabled = true
    #   }
    #   reservation_affinity = {
    #     enabled                  = false
    #     consume_reservation_type = null
    #     key                      = null
    #     values = []
    #   }
    #   queued_provisioning = {
    #     enabled = false
    #   }
    #   flex_start = {
    #     enabled = true
    #   }
    #   max_run_duration = {
    #     enabled = true # Required for flex start
    #     # 1 week in seconds
    #     duration = "604800s"
    #   }
    #   management = {
    #     auto_repair = true
    #     auto_upgrade = true
    #   }
    #   upgrade_settings = {
    #     max_surge       = 0
    #     max_unavailable = 0
    #     strategy        = "SURGE"
    #   }
    # },
    ] : [
    #{
    #  name         = "gke-default-g2-standard-48-pool"
    #  machine_type = "g2-standard-48"
    #  node_count   = null
    #  disk_size  = 1000
    #  autoscaling = {
    #    location_policy      = "ANY"
    #    min_node_count       = null
    #    max_node_count       = null
    #    total_min_node_count = 0
    #    total_max_node_count = 2
    #  }
    #  subnet = {
    #    name            = google_compute_subnetwork.deployment-subnet-app.name
    #    ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
    #    ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
    #  }
    #  vpc_id                = google_compute_network.vpc-deployment.id
    #  preemptible           = false
    #  service_account_email = google_service_account.gke_node_pool_service_account.email
    #  guest_accelerator = [
    #    {
    #      type  = "nvidia-l4"
    #      count = 4
    #    }
    #  ]
    #  gvnic = {
    #    enabled = true
    #  }
    #  reservation_affinity = {
    #    enabled                  = false
    #    consume_reservation_type = null
    #    key                      = null
    #    values = []
    #  }
    #  queued_provisioning = {
    #    enabled = false
    #  }
    #  flex_start = {
    #    enabled = false
    #  }
    #  max_run_duration = {
    #    enabled  = false
    #    duration = "0s"
    #  }
    #  management = {
    #    auto_repair  = true
    #    auto_upgrade = true
    #  }
    #  upgrade_settings = {
    #    max_surge       = 1
    #    max_unavailable = 1
    #    strategy        = "SURGE"
    #  }
    #},
    # g2-standard-96 (required to run the 7b models)
    #{
    #  name         = "gke-default-g2-standard-96-pool"
    #  machine_type = "g2-standard-96"
    #  node_count   = null
    #  disk_size  = 1000
    #  autoscaling = {
    #    location_policy      = "ANY"
    #    min_node_count       = null
    #    max_node_count       = 0
    #    total_min_node_count = null
    #    total_max_node_count = null
    #  }
    #  subnet = {
    #    name            = google_compute_subnetwork.deployment-subnet-app.name
    #    ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
    #    ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
    #  }
    #  vpc_id                = google_compute_network.vpc-deployment.id
    #  preemptible           = false
    #  service_account_email = google_service_account.gke_node_pool_service_account.email
    #  guest_accelerator = [
    #    {
    #      type  = "nvidia-l4"
    #      count = 8
    #    }
    #  ]
    #  gvnic = {
    #    enabled = true
    #  }
    #  reservation_affinity = {
    #    enabled                  = false
    #    consume_reservation_type = null
    #    key                      = null
    #    values = []
    #  }
    #  queued_provisioning = {
    #    enabled = false
    #  }
    #  flex_start = {
    #    enabled = false
    #  }
    #  max_run_duration = {
    #    enabled  = false
    #    duration = "0s"
    #  }
    #  management = {
    #    auto_repair  = true
    #    auto_upgrade = true
    #  }
    #  upgrade_settings = {
    #    max_surge       = 1
    #    max_unavailable = 1
    #    strategy        = "SURGE"
    #  }
    #},
    # c2-standard-8
    {
      name         = "gke-default-c2-standard-8-pool"
      machine_type = "c2-standard-8"
      node_count   = null
      disk_size    = 100
      autoscaling = {
        location_policy      = "BALANCED"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator     = []
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    {
      name         = "gke-default-g2-standard-8-pool"
      machine_type = "g2-standard-8"
      node_count   = null
      disk_size    = 100
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 1
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-l4"
          count = 1
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 1
        strategy        = "SURGE"
      }
    },
    # g4-standard-384-flex-pool
    {
      name         = "g4-standard-384-flex-pool"
      machine_type = "g4-standard-384"
      node_count   = 0
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 0
      }
      subnet = {
        name            = google_compute_subnetwork.deployment-subnet-app.name
        ip_cidr_range   = google_compute_subnetwork.deployment-subnet-app.ip_cidr_range
        ipv6_cidr_range = google_compute_subnetwork.deployment-subnet-app.ipv6_cidr_range
      }
      vpc_id                = google_compute_network.vpc-deployment.id
      preemptible           = false
      service_account_email = google_service_account.gke_node_pool_service_account.email
      guest_accelerator = [
        {
          type  = "nvidia-rtx-pro-6000"
          count = 8
        }
      ]
      gvnic = {
        enabled = true
      }
      reservation_affinity = {
        enabled                  = false
        consume_reservation_type = null
        key                      = null
        values                   = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = true
      }
      max_run_duration = {
        enabled = true # Required for flex start
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair  = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
  ]
  team             = "infra"
  gke_hub_fleet_id = google_gke_hub_fleet.default.display_name
}

# a provider config to target this cluster
data "google_container_cluster" "container-cluster-default-data" {
  depends_on = [module.container-cluster-default]
  name       = module.container-cluster-default[0].cluster_name
  location   = var.region_default
}

# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "google_client_config-for-container-cluster-default" {
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_gke_with_terraform
provider "kubernetes" {
  # Use the kubeconfig written by `gcloud container clusters get-credentials`
  # rather than reading the cluster endpoint/CA from the data source. The data
  # source is deferred when the cluster resource has pending changes, which
  # causes the kubernetes provider to fail with "no client config" during plan.
  config_path    = pathexpand("~/.kube/config")
  config_context = "gke_${google_project.deployment-project.project_id}_${var.region_default}_gke-default"
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
  alias = "kubernetes-provider-for-container-cluster-default"
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand("~/.kube/config")
    config_context = "gke_${google_project.deployment-project.project_id}_${var.region_default}_gke-default"
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
  alias = "helm-provider-for-container-cluster-default"
}

moved {
  from = module.container-cluster-gpus-default-config
  to   = module.container-cluster-default-config
}

module "container-cluster-default-config" {

  count = var.gke_default_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
    helm       = helm.helm-provider-for-container-cluster-default
  }
  depends_on = [
    module.container-cluster-default,
    data.google_client_config.google_client_config-for-container-cluster-default,
  ]
  source             = "../modules/create_gke_config"
  cloud_provider     = "gcp"
  project_id         = google_project.deployment-project.project_id
  cluster_name       = module.container-cluster-default[0].cluster_name
  cluster_name_short = module.container-cluster-default[0].cluster_name_short
  region             = var.region_default
  datadog_api_key    = data.google_secret_manager_secret_version.datadog_api_key.secret_data
  datadog_app_key    = data.google_secret_manager_secret_version.datadog_app_key.secret_data
  datadog_site       = var.datadog_site
  environment        = var.environment
  create_namespaces = [
    local.gke_workload_namespace_for_llm_apps,
    local.gke_workload_namespace_for_services_apps,
  ]
  enable_kube_state_metrics   = true
  enable_nvidia_dcgm_exporter = false
}

module "container-cluster-default-flex-start-a3-highgpu-pool-config" {
  # README: https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference
  # https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler
  count = var.gke_default_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  depends_on = [
    module.container-cluster-default,
    data.google_client_config.google_client_config-for-container-cluster-default,
  ]
  source                           = "../modules/create_gke_flexstart_compute_class"
  machine_type                     = "a3-highgpu-8g"
  compute_class_name               = "dws-model-inference-a3-highgpu-class"
  service_account_email            = google_service_account.gke_node_pool_service_account.email
  prioritize_spot_instances_first  = false
  max_run_duration_seconds         = 604800 # 7 days
  node_recycling_lead_time_seconds = 7200   # 2 hours
  boot_disk_size                   = 1024
  local_ssd_count                  = 16
}

module "container-cluster-default-flex-start-a3-highgpu-2g-pool-config" {
  # README: https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference
  # https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler
  count = var.gke_default_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  depends_on = [
    module.container-cluster-default,
    data.google_client_config.google_client_config-for-container-cluster-default,
  ]
  source                           = "../modules/create_gke_flexstart_compute_class"
  machine_type                     = "a3-highgpu-2g"
  compute_class_name               = "dws-model-inference-a3-highgpu-2g-class"
  service_account_email            = google_service_account.gke_node_pool_service_account.email
  prioritize_spot_instances_first  = false
  max_run_duration_seconds         = 604800 # 7 days
  node_recycling_lead_time_seconds = 7200   # 2 hours
  boot_disk_size                   = 1024
  local_ssd_count                  = 4
}

module "container-cluster-default-flex-start-a3-highgpu-1g-pool-config" {
  # README: https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference
  count = var.gke_default_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  depends_on = [
    module.container-cluster-default,
    data.google_client_config.google_client_config-for-container-cluster-default,
  ]
  source                           = "../modules/create_gke_flexstart_compute_class"
  machine_type                     = "a3-highgpu-1g"
  compute_class_name               = "dws-model-inference-a3-highgpu-1g-class"
  service_account_email            = google_service_account.gke_node_pool_service_account.email
  prioritize_spot_instances_first  = false
  max_run_duration_seconds         = 604800 # 7 days
  node_recycling_lead_time_seconds = 7200   # 2 hours
  boot_disk_size                   = 1024
  local_ssd_count                  = 2
  gpu_type                         = "nvidia-h100-80gb"
  gpu_count                        = 1
}

moved {
  from = module.container-cluster-keda-config
  to   = module.container-cluster-default-keda-config
}

module "container-cluster-default-keda-config" {

  count = var.gke_default_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
    helm       = helm.helm-provider-for-container-cluster-default
  }
  depends_on = [
    module.container-cluster-default,
    data.google_client_config.google_client_config-for-container-cluster-default,
  ]
  source                           = "../modules/create_gke_config_keda"
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  cluster_name                     = module.container-cluster-default[0].cluster_name
  cluster_name_short               = module.container-cluster-default[0].cluster_name_short
  region                           = var.region_default
  environment                      = var.environment
  gke_namespaces                   = local.gke_all_workload_namespaces
  gke_dns_cluster_domain           = local.gke_default_cluster_domain_dns
  gke_cluster_name                 = module.container-cluster-default[0].cluster_name
  datadog_site                     = var.datadog_site
  datadog_cluster_agent_namespace  = module.container-cluster-default-config[0].datadog_cluster_agent_namespace
  datadog_cluster_agent_service    = module.container-cluster-default-config[0].datadog_cluster_agent_service
  datadog_cluster_agent_unsafe_ssl = local.datadog_cluster_agent_unsafe_ssl
}
