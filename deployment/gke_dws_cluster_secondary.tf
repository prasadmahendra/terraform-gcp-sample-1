locals {
  gke_dws_cluster_secondary_name_suffix            = replace(var.gke_dws_secondary_cluster_region, "_", "-")
  gke_dws_cluster_secondary_region                 = local.vpc_app_subnets_map[var.gke_dws_secondary_cluster_region].region
  gke_dws_cluster_secondary_subnet_name            = local.vpc_app_subnets_map[var.gke_dws_secondary_cluster_region].subnet_name
  gke_dws_cluster_secondary_subnet_ip_cidr_range   = local.vpc_app_subnets_map[var.gke_dws_secondary_cluster_region].subnet_ip_cidr_range
  gke_dws_cluster_secondary_subnet_ipv6_cidr_range = local.vpc_app_subnets_map[var.gke_dws_secondary_cluster_region].subnet_ipv6_cidr_range
  gke_dws_cluster_secondary_compute_zones          = var.gke_dws_secondary_cluster_compute_zones
}

module "gke-dws-cluster-secondary" {
  count = var.gke_dws_secondary_cluster_enabled && var.environment == "dev" ? 1 : 0
  depends_on = [
    google_compute_router_nat.nat
  ]
  environment                = var.environment
  source                     = "../modules/create_gke"
  cluster_name               = "gke-dws-2-${local.gke_dws_cluster_secondary_name_suffix}"
  cluster_name_short         = "gke-dws-2-${local.gke_dws_cluster_secondary_name_suffix}"
  dns_config_services_domain = "gke-dws-2-${local.gke_dws_cluster_secondary_name_suffix}.${var.environment}.${var.root_domain}"
  project_id                 = google_project.deployment-project.project_id
  project_number             = google_project.deployment-project.number
  region                     = local.gke_dws_cluster_secondary_region
  node_locations             = local.gke_dws_cluster_secondary_compute_zones
  subnet = {
    name            = local.gke_dws_cluster_secondary_subnet_name
    ip_cidr_range   = local.gke_dws_cluster_secondary_subnet_ip_cidr_range
    ipv6_cidr_range = local.gke_dws_cluster_secondary_subnet_ipv6_cidr_range
  }
  vpc_name                              = google_compute_network.vpc-deployment.name
  remove_default_node_pool              = true
  cluster_autoscaling_profile           = "OPTIMIZE_UTILIZATION"
  notification_config_topic             = google_pubsub_topic.gke-cluster-notifications.id
  autopilot_nodes_service_account_email = google_service_account.gke_node_pool_service_account.email
  auto_provisioning_defaults_enabled    = false
  enable_private_nodes                  = true
  node_pools = [
    {
      name         = "gke-dws-cluster-secondary-e2-pool"
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
        auto_upgrade = false
      }
      upgrade_settings = {
        max_surge       = 1
        max_unavailable = 0
        strategy        = null
      }
    },
    {
      name         = "gke-secondary-g4-standard-384-dws-pool"
      machine_type = "g4-standard-384"
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
        enabled = true
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
        auto_upgrade = false
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

data "google_container_cluster" "gke-dws-cluster-secondary-data" {
  count      = var.gke_dws_secondary_cluster_enabled && var.environment == "dev" ? 1 : 0
  depends_on = [module.gke-dws-cluster-secondary]
  name       = module.gke-dws-cluster-secondary[0].cluster_name
  location   = local.gke_dws_cluster_secondary_region
}

data "google_client_config" "google_client_config-for-gke-dws-cluster-secondary" {
}

provider "kubernetes" {
  host  = "https://${try(data.google_container_cluster.gke-dws-cluster-secondary-data[0].endpoint, "localhost")}"
  token = data.google_client_config.google_client_config-for-gke-dws-cluster-secondary.access_token
  cluster_ca_certificate = base64decode(
    try(data.google_container_cluster.gke-dws-cluster-secondary-data[0].master_auth[0].cluster_ca_certificate, "")
  )
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
  alias = "kubernetes-provider-for-gke-dws-cluster-secondary"
}

provider "helm" {
  kubernetes {
    host  = "https://${try(data.google_container_cluster.gke-dws-cluster-secondary-data[0].endpoint, "localhost")}"
    token = data.google_client_config.google_client_config-for-gke-dws-cluster-secondary.access_token
    cluster_ca_certificate = base64decode(
      try(data.google_container_cluster.gke-dws-cluster-secondary-data[0].master_auth[0].cluster_ca_certificate, "")
    )
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "gke-gcloud-auth-plugin"
    }
  }
  alias = "helm-provider-for-gke-dws-cluster-secondary"
}

provider "kubectl" {
  host  = "https://${try(data.google_container_cluster.gke-dws-cluster-secondary-data[0].endpoint, "localhost")}"
  token = data.google_client_config.google_client_config-for-gke-dws-cluster-secondary.access_token
  cluster_ca_certificate = base64decode(
    try(data.google_container_cluster.gke-dws-cluster-secondary-data[0].master_auth[0].cluster_ca_certificate, "")
  )
  load_config_file = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
  alias = "kubectl-provider-for-gke-dws-cluster-secondary"
}

module "gke-dws-cluster-secondary-config" {
  count = var.gke_dws_secondary_cluster_enabled && var.environment == "dev" ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-gke-dws-cluster-secondary
    helm       = helm.helm-provider-for-gke-dws-cluster-secondary
  }
  depends_on = [
    module.gke-dws-cluster-secondary,
    data.google_client_config.google_client_config-for-gke-dws-cluster-secondary,
  ]
  source             = "../modules/create_gke_config"
  cloud_provider     = "gcp"
  project_id         = google_project.deployment-project.project_id
  cluster_name       = module.gke-dws-cluster-secondary[0].cluster_name
  cluster_name_short = module.gke-dws-cluster-secondary[0].cluster_name_short
  region             = local.gke_dws_cluster_secondary_region
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

module "gke-dws-cluster-secondary-dws-config" {
  count = var.gke_dws_secondary_cluster_enabled && var.environment == "dev" ? 1 : 0
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-gke-dws-cluster-secondary
    helm       = helm.helm-provider-for-gke-dws-cluster-secondary
    kubectl    = kubectl.kubectl-provider-for-gke-dws-cluster-secondary
  }
  depends_on = [
    module.gke-dws-cluster-secondary,
    data.google_client_config.google_client_config-for-gke-dws-cluster-secondary,
    module.gke-dws-cluster-secondary-config,
  ]
  source                   = "../modules/create_gke_dws_config"
  project_id               = google_project.deployment-project.project_id
  region                   = local.gke_dws_cluster_secondary_region
  environment              = var.environment
  local_queue_name         = "dws-local-queue-secondary"
  cluster_queue_name       = "dws-cluster-queue-secondary"
  resource_flavor_name     = "default-flavor-secondary"
  provisioning_config_name = "dws-config-secondary"
  namespace                = local.gke_workload_namespace_for_services_apps
}
