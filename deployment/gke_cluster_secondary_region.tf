locals {
  gke_secondary_region_clusters_enabled = var.gke_secondary_region_clusters_enabled
}

moved {
  from = module.container-cluster-us-west1
  to   = module.container-cluster-secondary-region
}

# GPU computing GKE cluster
module "container-cluster-secondary-region" {

  count = local.gke_secondary_region_clusters_enabled ? 1 : 0
  depends_on = [
    google_compute_router_nat.nat
  ]
  environment                = var.environment
  source                     = "../modules/create_gke"
  cluster_name               = "gke-${var.region_secondary}"
  cluster_name_short         = "gke-${var.region_secondary}"
  dns_config_services_domain = "gke-${var.region_secondary}.${var.environment}.${var.root_domain}"
  project_id                 = google_project.deployment-project.project_id
  project_number             = google_project.deployment-project.number
  region                     = var.region_secondary
  node_locations             = var.compute_zones_gpus_secondary_region
  release_channel            = "REGULAR"
  subnet = {
    name            = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].name
    ip_cidr_range   = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].ip_cidr_range
    ipv6_cidr_range = google_compute_subnetwork.deployment-secondary-region-subnet-app[0].ipv6_cidr_range
  }
  vpc_name                    = google_compute_network.vpc-deployment.name
  remove_default_node_pool = true
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#autoscaling_profile
  cluster_autoscaling_profile = "OPTIMIZE_UTILIZATION"
  notification_config_topic   = google_pubsub_topic.gke-cluster-notifications.id
  autopilot_nodes_service_account_email = google_service_account.gke_node_pool_service_account.email
  auto_provisioning_defaults_enabled    = true

  # GPU machine types:
  # https://cloud.google.com/compute/docs/gpus
  # Note - GPUs aren't available in all zones (must restrict cluster-zone to get desired results!)
  # https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
  enable_private_nodes = true
  node_pools           = var.environment == "prod" ? [
    # a3-highgpu-8g
    {
      name         = "gke-default-a3-highgpu-8g-pool"
      machine_type = "a3-highgpu-8g"
      node_count = null
      disk_size = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 1
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
        values = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
        node_recycling = {
          lead_time_seconds = 0
        }
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
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a3-highgpu-8g-flex-pool
    {
      name         = "a3-highgpu-8g-calmode-pool"
      machine_type = "a3-highgpu-8g"
      node_count = 0
      disk_size = 1000
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
        enabled                  = true
        consume_reservation_type = "SPECIFIC_RESERVATION"
        key                      = "compute.googleapis.com/reservation-name"
        values = ["inference-surge-calendar-block-us-west1-b"]
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
        node_recycling = {
          lead_time_seconds = 0
        }
      }
      max_run_duration = {
        enabled = false
        # 1 week in seconds
        duration = "604800s"
      }
      management = {
        auto_repair = true
        auto_upgrade = true
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
  ] : [
    # a3-highgpu-8g
    {
      name         = "gke-default-a3-highgpu-8g-pool"
      machine_type = "a3-highgpu-8g"
      node_count = null
      disk_size = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = 0
        total_min_node_count = null
        total_max_node_count = null
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
        values = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
        node_recycling = {
          lead_time_seconds = 0
        }
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
        max_unavailable = 0
        strategy        = "SURGE"
      }
    },
    # a2-ultragpu-2g
    {
      name         = "gke-default-a2-ultragpu-2g-pool"
      machine_type = "a2-ultragpu-2g"
      node_count = null
      disk_size = 700
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
          type  = "nvidia-a100-80gb"
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
        values = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
        node_recycling = {
          lead_time_seconds = 0
        }
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
    # n1-standard-4 with t4
    {
      name         = "gke-n1-standard-4-tesla-t4-pool"
      machine_type = "n1-standard-4"
      node_count = null
      disk_size = 100
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = 1
        total_min_node_count = null
        total_max_node_count = null
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
          type  = "nvidia-tesla-t4"
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
        values = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
        node_recycling = {
          lead_time_seconds = 0
        }
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
    # a3-highgpu-2g-flex-pool
    {
      name         = "a3-highgpu-2g-flex-pool"
      machine_type = "a3-highgpu-2g"
      node_count   = 0
      disk_size  = 1000
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
        values = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = true
        node_recycling = {
          lead_time_seconds : 7200 # 2 hours
        }
      }
      max_run_duration = {
        enabled  = true # Required for flex start
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
    # a2-ultragpu-1g
    {
      name         = "gke-default-a2-ultragpu-1g-pool"
      machine_type = "a2-ultragpu-1g"
      node_count = null
      disk_size = 350
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
          type  = "nvidia-a100-80gb"
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
        values = []
      }
      queued_provisioning = {
        enabled = false
      }
      flex_start = {
        enabled = false
        node_recycling = {
          lead_time_seconds = 0
        }
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
  ]
  team             = "infra"
  gke_hub_fleet_id = google_gke_hub_fleet.default.display_name
}

# a provider config to target this cluster
data "google_container_cluster" "container-cluster-secondary-region-data" {
  depends_on = [module.container-cluster-secondary-region]
  # we point this at container-cluster-gpus-default even though its wrong because we need to have a cluster to point at when west1 cluster is disabled!
  name     = local.gke_secondary_region_clusters_enabled ? module.container-cluster-secondary-region[0].cluster_name : module.container-cluster-default[0].cluster_name
  location = local.gke_secondary_region_clusters_enabled ? var.region_secondary : var.region_default
}

# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "google_client_config-for-container-cluster-secondary-region" {
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_gke_with_terraform
provider "kubernetes" {
  host  = "https://${data.google_container_cluster.container-cluster-secondary-region-data.endpoint}"
  token = data.google_client_config.google_client_config-for-container-cluster-secondary-region.access_token
  cluster_ca_certificate = base64decode(
      local.gke_secondary_region_clusters_enabled ?
      data.google_container_cluster.container-cluster-secondary-region-data.master_auth[0].cluster_ca_certificate : "bm9vcA==",
  )
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
  alias = "kubernetes-provider-for-container-cluster-secondary-region"
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.container-cluster-secondary-region-data.endpoint}"
    token = data.google_client_config.google_client_config-for-container-cluster-secondary-region.access_token
    cluster_ca_certificate = base64decode(
        local.gke_secondary_region_clusters_enabled ?
        data.google_container_cluster.container-cluster-secondary-region-data.master_auth[0].cluster_ca_certificate :
        "bm9vcA==",
    )
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
  alias = "helm-provider-for-container-cluster-secondary-region"
}

moved {
  from = module.container-cluster-us-west1-config
  to   = module.container-cluster-secondary-region-config
}

module "container-cluster-secondary-region-config" {

  count = local.gke_secondary_region_clusters_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-secondary-region
    helm       = helm.helm-provider-for-container-cluster-secondary-region
  }
  depends_on = [
    module.container-cluster-secondary-region,
    data.google_client_config.google_client_config-for-container-cluster-secondary-region,
  ]
  source             = "../modules/create_gke_config"
  cloud_provider     = "gcp"
  project_id         = google_project.deployment-project.project_id
  cluster_name       = module.container-cluster-secondary-region[0].cluster_name
  cluster_name_short = module.container-cluster-secondary-region[0].cluster_name_short
  region             = var.region_secondary
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

module "container-cluster-secondary-flex-start-a3-highgpu-pool-config" {
  # README: https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference
  # https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler
  count = var.gke_secondary_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-secondary-region
  }
  depends_on = [
    module.container-cluster-secondary-region,
    data.google_client_config.google_client_config-for-container-cluster-secondary-region,
  ]
  source                           = "../modules/create_gke_flexstart_compute_class"
  machine_type                     = "a3-highgpu-8g"
  compute_class_name               = "dws-model-inference-a3-highgpu-class"
  service_account_email            = google_service_account.gke_node_pool_service_account.email
  prioritize_spot_instances_first  = false
  max_run_duration_seconds = 604800  # 7 days
  node_recycling_lead_time_seconds = 7200 # 2 hours
  boot_disk_size = 1024
  local_ssd_count = 16
}

module "container-cluster-secondary-flex-start-a3-highgpu-2g-pool-config" {
  # README: https://cloud.google.com/kubernetes-engine/docs/how-to/dws-flex-start-inference
  # https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler
  count = var.gke_secondary_region_clusters_enabled && local.gke_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-secondary-region
  }
  depends_on = [
    module.container-cluster-secondary-region,
    data.google_client_config.google_client_config-for-container-cluster-secondary-region,
  ]
  source                           = "../modules/create_gke_flexstart_compute_class"
  machine_type                     = "a3-highgpu-2g"
  compute_class_name               = "dws-model-inference-a3-highgpu-2g-class"
  service_account_email            = google_service_account.gke_node_pool_service_account.email
  prioritize_spot_instances_first  = false
  max_run_duration_seconds = 604800  # 7 days
  node_recycling_lead_time_seconds = 7200 # 2 hours
  boot_disk_size = 1024
  local_ssd_count = 4
}

module "container-cluster-secondary-keda-config" {

  count = var.gke_secondary_region_clusters_enabled && local.gke_cluster_enabled ? 0 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-secondary-region
    helm       = helm.helm-provider-for-container-cluster-secondary-region
  }
  depends_on = [
    module.container-cluster-secondary-region,
    data.google_client_config.google_client_config-for-container-cluster-secondary-region,
  ]
  source                           = "../modules/create_gke_config_keda"
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  cluster_name                     = module.container-cluster-secondary-region[0].cluster_name
  cluster_name_short               = module.container-cluster-secondary-region[0].cluster_name_short
  region                           = var.region_secondary
  environment                      = var.environment
  gke_namespaces                   = local.gke_all_workload_namespaces
  gke_dns_cluster_domain           = local.gke_default_cluster_domain_dns
  gke_cluster_name                 = module.container-cluster-secondary-region[0].cluster_name
  datadog_site                     = var.datadog_site
  datadog_cluster_agent_namespace  = module.container-cluster-secondary-region-config[0].datadog_cluster_agent_namespace
  datadog_cluster_agent_service    = module.container-cluster-secondary-region-config[0].datadog_cluster_agent_service
  datadog_cluster_agent_unsafe_ssl = local.datadog_cluster_agent_unsafe_ssl
}
