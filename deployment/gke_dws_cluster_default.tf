locals {
  gke_dws_cluster_default_name_suffix            = replace(var.gke_dws_default_cluster_region, "_", "-")
  gke_dws_cluster_default_region                 = local.vpc_app_subnets_map[var.gke_dws_default_cluster_region].region
  gke_dws_cluster_default_subnet_name            = local.vpc_app_subnets_map[var.gke_dws_default_cluster_region].subnet_name
  gke_dws_cluster_default_subnet_ip_cidr_range   = local.vpc_app_subnets_map[var.gke_dws_default_cluster_region].subnet_ip_cidr_range
  gke_dws_cluster_default_subnet_ipv6_cidr_range = local.vpc_app_subnets_map[var.gke_dws_default_cluster_region].subnet_ipv6_cidr_range
}

module "gke-dws-cluster-default" {

  count = var.gke_dws_default_cluster_enabled ? 1 : 0
  depends_on = [
    google_compute_router_nat.nat
  ]
  environment                = var.environment
  source                     = "../modules/create_gke"
  cluster_name               = "gke-dws-${local.gke_dws_cluster_default_name_suffix}"
  cluster_name_short         = "gke-dws-${local.gke_dws_cluster_default_name_suffix}"
  dns_config_services_domain = "gke-dws-${local.gke_dws_cluster_default_name_suffix}.${var.environment}.${var.root_domain}"
  project_id                 = google_project.deployment-project.project_id
  project_number             = google_project.deployment-project.number
  region                     = local.gke_dws_cluster_default_region
  node_locations             = var.gke_dws_default_cluster_compute_zones
  subnet = {
    name            = local.gke_dws_cluster_default_subnet_name
    ip_cidr_range   = local.gke_dws_cluster_default_subnet_ip_cidr_range
    ipv6_cidr_range = local.gke_dws_cluster_default_subnet_ipv6_cidr_range
  }
  vpc_name                 = google_compute_network.vpc-deployment.name
  remove_default_node_pool = true
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#autoscaling_profile
  cluster_autoscaling_profile           = "OPTIMIZE_UTILIZATION"
  notification_config_topic             = google_pubsub_topic.gke-cluster-notifications.id
  autopilot_nodes_service_account_email = google_service_account.gke_node_pool_service_account.email
  auto_provisioning_defaults_enabled    = false

  # GPU machine types:
  # https://cloud.google.com/compute/docs/gpus
  # Note - GPUs aren't available in all zones (must restrict cluster-zone to get desired results!)
  # https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
  enable_private_nodes = true
  node_pools = var.environment == "prod" ? [
    {
      # we need 1 small pool for the default workload, dd agent etc
      name         = "gke-dws-cluster-default-e2-pool"
      machine_type = "e2-standard-4"
      node_count   = null
      disk_size    = 100
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 10
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
        auto_upgrade = false
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = null
      }
    },
    # a2-ultragpu-8g (for dynamic workload scheduler)
    {
      name         = "gke-default-a2-ultragpu-8g-dws-pool"
      machine_type = "a2-ultragpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # gke-default-a3-highgpu-8g-pool
    {
      name         = "gke-default-a3-highgpu-8g-dws-pool"
      machine_type = "a3-highgpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # a2-ultragpu-2g (for debugging vllm)
    {
      name         = "gke-default-a2-ultragpu-2g-dws-pool"
      machine_type = "a2-ultragpu-2g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        values                   = []
      }
      queued_provisioning = {
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # g2-standard-96
    {
      name         = "gke-default-g2-standard-96-dws-pool"
      machine_type = "g2-standard-96"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    ] : [
    {
      # we need 1 small pool for the default workload, dd agent etc
      name         = "gke-dws-cluster-default-e2-pool"
      machine_type = "e2-standard-4"
      node_count   = null
      disk_size    = 100
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 10
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
        auto_upgrade = false
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = null
      }
    },
    # a2-ultragpu-8g (for dynamic workload scheduler)
    {
      name         = "gke-default-a2-ultragpu-8g-dws-pool"
      machine_type = "a2-ultragpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # gke-default-a3-highgpu-8g-pool
    {
      name         = "gke-default-a3-highgpu-8g-dws-pool"
      machine_type = "a3-highgpu-8g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # gke-default-a3-highgpu-2g-pool
    {
      name         = "gke-default-a3-highgpu-2g-dws-pool"
      machine_type = "a3-highgpu-2g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # gke-default-a3-highgpu-4g-pool
    {
      name         = "gke-default-a3-highgpu-4g-dws-pool"
      machine_type = "a3-highgpu-4g"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
    # g2-standard-96
    {
      name         = "gke-default-g2-standard-96-dws-pool"
      machine_type = "g2-standard-96"
      node_count   = null
      disk_size    = 1000
      autoscaling = {
        location_policy      = "ANY"
        min_node_count       = null
        max_node_count       = null
        total_min_node_count = 0
        total_max_node_count = 6
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
        enabled = true
      }
      flex_start = {
        enabled = false
      }
      max_run_duration = {
        enabled  = false
        duration = "0s"
      }
      management = {
        auto_repair  = true  # to avoid auto-repair of nodes and work disruption
        auto_upgrade = false # to avoid auto-upgrade of nodes and work disruption
      }
      upgrade_settings = {
        max_surge       = 0
        max_unavailable = 0
        strategy        = null
      }
    },
  ]
  team             = "infra"
  gke_hub_fleet_id = google_gke_hub_fleet.default.display_name
  release_channel  = "UNSPECIFIED"
}


# a provider config to target this cluster
data "google_container_cluster" "gke-dws-cluster-default-data" {
  depends_on = [module.gke-dws-cluster-default]
  name       = module.gke-dws-cluster-default[0].cluster_name
  location   = local.gke_dws_cluster_default_region
}

# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "google_client_config-for-gke-dws-cluster-default" {
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/using_gke_with_terraform
provider "kubernetes" {
  host  = "https://${data.google_container_cluster.gke-dws-cluster-default-data.endpoint}"
  token = data.google_client_config.google_client_config-for-gke-dws-cluster-default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.gke-dws-cluster-default-data.master_auth[0].cluster_ca_certificate,
  )
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
  alias = "kubernetes-provider-for-gke-dws-cluster-default"
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.gke-dws-cluster-default-data.endpoint}"
    token = data.google_client_config.google_client_config-for-gke-dws-cluster-default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.gke-dws-cluster-default-data.master_auth[0].cluster_ca_certificate,
    )
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
  alias = "helm-provider-for-gke-dws-cluster-default"
}

provider "kubectl" {
  host  = "https://${data.google_container_cluster.gke-dws-cluster-default-data.endpoint}"
  token = data.google_client_config.google_client_config-for-gke-dws-cluster-default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.gke-dws-cluster-default-data.master_auth[0].cluster_ca_certificate,
  )
  load_config_file = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
  alias = "kubectl-provider-for-gke-dws-cluster-default"
}

module "gke-dws-cluster-default-config" {

  count = var.gke_dws_default_cluster_enabled ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-gke-dws-cluster-default
    helm       = helm.helm-provider-for-gke-dws-cluster-default
  }
  depends_on = [
    module.gke-dws-cluster-default,
    data.google_client_config.google_client_config-for-gke-dws-cluster-default,
  ]
  source             = "../modules/create_gke_config"
  cloud_provider     = "gcp"
  project_id         = google_project.deployment-project.project_id
  cluster_name       = module.gke-dws-cluster-default[0].cluster_name
  cluster_name_short = module.gke-dws-cluster-default[0].cluster_name_short
  region             = local.gke_dws_cluster_default_region
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

module "gke-dws-cluster-default-dws-config" {

  count = var.gke_dws_default_cluster_enabled && var.environment == "dev" ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-gke-dws-cluster-default
    helm       = helm.helm-provider-for-gke-dws-cluster-default
    kubectl    = kubectl.kubectl-provider-for-gke-dws-cluster-default
  }
  depends_on = [
    module.gke-dws-cluster-default,
    data.google_client_config.google_client_config-for-gke-dws-cluster-default,
    module.gke-dws-cluster-default-config
  ]
  source                   = "../modules/create_gke_dws_config"
  project_id               = google_project.deployment-project.project_id
  region                   = local.gke_dws_cluster_default_region
  environment              = var.environment
  local_queue_name         = "dws-local-queue"
  cluster_queue_name       = "dws-cluster-queue"
  resource_flavor_name     = "default-flavor"
  provisioning_config_name = "dws-config"
  namespace                = local.gke_workload_namespace_for_services_apps
}
