locals {
  domain_name_suffix               = var.environment == "prod" ? var.root_domain : "${var.environment}.${var.root_domain}"
  domain_name_suffix_rebrand       = var.environment == "prod" ? local.rebrand_dns_root : "${var.environment}.${local.rebrand_dns_root}"
  public_dns_zone_name             = google_dns_managed_zone.public-zone.name
  public_dns_zone_provider         = "google"
  public_dns_zone_name_rebrand     = google_dns_managed_zone.public-zone-envive.name
  public_dns_zone_provider_rebrand = "google"
}

module "webapp-admin" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name       = "webapp-admin"
  source             = "./services/webapp-admin"
  environment        = var.environment
  project_id         = var.project_id
  docker_image       = module.git-repo-webapp-admin[0].docker_image
  docker_image_tag   = var.environment == "prod" ? module.git-repo-webapp-admin[0].docker_image_prod_tag : module.git-repo-webapp-admin[0].docker_image_latest_tag
  region             = var.region_default
  subnet             = google_compute_subnetwork.deployment-subnet-app.name
  domain_name_public = "platform.${local.domain_name_suffix_rebrand}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name_rebrand
    provider = local.public_dns_zone_provider_rebrand
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone-envive.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site                 = var.datadog_site
  datadog_trace_enabled        = true
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex_v2.name
  cluster_name                 = module.container-cluster-default[0].cluster_name
  cluster_region               = module.container-cluster-default[0].cluster_region
  cluster_namespace            = local.gke_workload_namespace_for_services_apps
  project_number               = google_project.deployment-project.number
  team                         = "ai-studio"
  chapter                      = "frontend"
}

module "api-internal" {

  depends_on = [
    google_project_service.all,
    google_firestore_database.spiffy-annotations-store,
    google_redis_cluster.redis-cluster-default,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  source = "./services/api-internal"
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name       = "api-internal"
  environment        = var.environment
  project_id         = var.project_id
  docker_image       = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag   = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region             = var.region_default
  subnet             = google_compute_subnetwork.deployment-subnet-app.name
  domain_name_public = "api.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_app_key = {
    secret  = data.google_secret_manager_secret_version.datadog_app_key.secret
    version = data.google_secret_manager_secret_version.datadog_app_key.version
  }
  datadog_site                 = var.datadog_site
  datadog_trace_enabled        = true
  database_connection_name     = module.main-db.instance_connection_name
  datastore_id                 = google_firestore_database.spiffy-annotations-store.id
  redis_host                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  gke_cluster_name             = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace        = local.gke_workload_namespace_for_services_apps
  cloudsql_instance_name       = module.main-db.instance_name
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  project_number               = google_project.deployment-project.number
  temporal_host                = var.temporal_host
  dev_api_internal_service_account_email = var.environment == "prod" ? data.terraform_remote_state.dev.outputs.api_internal_service_account_email : null
}

module "mcp" {
  depends_on = [
    google_project_service.all,
    google_redis_cluster.redis-cluster-default,
    data.google_container_cluster.container-cluster-default-data,
  ]
  source = "./services/mcp"
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  count            = contains(["dev", "prod"], var.environment) ? 1 : 0
  service_name     = "mcp"
  environment      = var.environment
  project_id       = var.project_id
  docker_image     = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region           = var.region_default
  subnet           = google_compute_subnetwork.deployment-subnet-app.name
  # mcp.envive.ai (prod) / mcp.dev.envive.ai (dev)
  domain_name_public = "mcp.${local.domain_name_suffix_rebrand}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name_rebrand
    provider = local.public_dns_zone_provider_rebrand
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone-envive.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_app_key = {
    secret  = data.google_secret_manager_secret_version.datadog_app_key.secret
    version = data.google_secret_manager_secret_version.datadog_app_key.version
  }
  datadog_site                 = var.datadog_site
  datadog_trace_enabled        = true
  database_connection_name     = module.main-db.instance_connection_name
  redis_host                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  gke_cluster_name             = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace        = local.gke_workload_namespace_for_services_apps
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex_v2.name
  project_number               = google_project.deployment-project.number
}

module "sentence-transformer" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                       = "./services/sentence-transformer"
  count = contains(["dev", "prod"], var.environment) ? 0 : 0 # Disabled in dev or prod
  service_name                 = "sentence-transformer"
  environment                  = var.environment
  gke_cluster_name             = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace        = local.gke_workload_namespace_for_services_apps
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  project_id                   = var.project_id
  project_number               = google_project.deployment-project.number
  docker_image                 = null
  docker_image_tag             = null
  region                       = var.region_default
  vpc_name                     = google_compute_network.vpc-deployment.name
  domain_name_public           = "sentence-transformer.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site          = var.datadog_site
  datadog_trace_enabled = true
  gpu_accelerator_type  = "nvidia-l4"
  gpu_accelerator_count = 1
}

module "retrieval-api" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                       = "./services/retrieval-api"
  count = contains(["dev", "prod"], var.environment) ? 0 : 0 # Disabled in dev or prod
  service_name                 = "retrieval-api"
  environment                  = var.environment
  gke_cluster_name             = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace        = local.gke_workload_namespace_for_services_apps
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  project_id                   = var.project_id
  project_number               = google_project.deployment-project.number
  docker_image                 = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag             = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region                       = var.region_default
  subnet                       = google_compute_subnetwork.deployment-subnet-app.name
  vpc_name                     = google_compute_network.vpc-deployment.name
  domain_name_public           = "retrieval-api.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site             = var.datadog_site
  datadog_trace_enabled    = true
  database_connection_name = module.main-db.instance_connection_name
  datastore_id             = google_firestore_database.spiffy-annotations-store.id
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
}

module "retrieval-search-indexing-service" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
    module.container-cluster-default-config,
    module.container-cluster-default-keda-config
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/retrieval-search-indexing"
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name                   = "retrieval-search-indexing"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id               = google_project.deployment-project.project_id
  project_number           = google_project.deployment-project.number
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                   = var.region_default
  vpc_name                 = google_compute_network.vpc-deployment.name
  cloudsql_instance_name   = module.main-db.instance_name
  database_connection_name = module.main-db.instance_connection_name
  temporal_host            = var.temporal_host
  temporal_namespace       = var.temporal_namespace
  text_embed_endpoint_url  = var.text_embed_endpoint_url
}

moved {
  from = module.llm-inference-service-set
  to   = module.llm-inference-service-set-default-region
}

module "llm-inference-service-set-default-region" {

  count = 1
  depends_on = [
    module.container-cluster-default-config,
    data.google_container_cluster.container-cluster-default-data,
  ]
  source                = "./services/llm-inference-set"
  region_codes          = local.region_codes
  gke_cluster_name      = module.container-cluster-default[0].cluster_name
  gke_cluster_region    = module.container-cluster-default[0].cluster_region
  gke_cluster_namespace = local.gke_workload_namespace_for_llm_apps
  gke_cluster_subnet    = module.container-cluster-default[0].cluster_subnet
  docker_image          = module.git-repo-vllm[0].docker_image
  docker_image_tag      = var.environment == "prod" ? module.git-repo-vllm[0].docker_image_prod_tag : module.git-repo-vllm[0].docker_image_latest_tag
  environment           = var.environment
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  project_id                     = var.project_id
  project_number                 = google_project.deployment-project.number
  vpc_name                       = google_compute_network.vpc-deployment.name
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  service_set_name        = "llm-inference-svc"
  service_gcs_bucket_name = google_storage_bucket.llm-inference-service-gcs-bucket.name
  inference_service_config = [
    {
      enabled                          = false
      model_name                       = "llama-2-7b-base",
      model_config                     = "vllm_7b_1x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "na" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 5
      cpu_alloc_min                    = 2
      memory_alloc_max                 = "80Gi"
      memory_alloc_min                 = "2Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-2-7b-chat",
      model_config                     = "vllm_7b_1x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "chat" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-chat-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 5
      cpu_alloc_min                    = 2
      memory_alloc_max                 = "80Gi"
      memory_alloc_min                 = "2Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-2-70b-chat",
      model_config                     = "vllm_70b_8x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 8
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "70b-chat" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-70b-chat-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 15
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "320Gi"
      memory_alloc_min                 = "320Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-2-70b-chat",
      model_config                     = "vllm_70b_8x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 8
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "70b-chat" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-70b-chat-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 15
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "320Gi"
      memory_alloc_min                 = "320Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 8
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-70b-l4-${local.region_codes[var.region_default]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-l4-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 24
      cpu_alloc_min                    = 18
      memory_alloc_max                 = "360Gi"
      memory_alloc_min                 = "340Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = [
        "--max_loras", "4",
        "--max_num_batched_tokens", "16384",
        "--backlog", "4",
        "--max_num_seqs", "16",
        "--gpus", "0,1,2,3,4,5,6,7",
        "--tensor_parallel_size", "8", # must match gpu_accelerator_count
        "--gpu_memory_utilization", "0.95"
      ]
      docker_image_override     = null
      docker_image_tag_override = null
    },
    {
      enabled                          = false
      model_name                       = "llama-3-8b-instruct",
      model_config                     = "this-config-does-not-exist.json", # MP: I don't think this used
      gpu_accelerator_type             = "nvidia-a100-80gb",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-8b-${local.region_codes[var.region_default]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-8b-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 4
      cpu_alloc_min                    = 4
      memory_alloc_max                 = "120Gi"
      memory_alloc_min                 = "120Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 2
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_llama8b_1xa100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0", # gpu
        "llama-3.1-8b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.6.6.post1_20250731"   # old -- "v0.6.6.post1_20250430"
    },
    {
      enabled                          = false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 4
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-70b-${local.region_codes[var.region_default]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 90
      cpu_alloc_min                    = 90
      memory_alloc_max                 = "840Gi"
      memory_alloc_min                 = "840Gi"
      set_shm_to_memory                = true
      number_of_replicas               = var.environment == "prod" ? 0 : 0
      number_of_replicas_spot_capacity = null # null = destroy spot-cap deployment; 0 leaves it alive for KEDA to scale → P1 alert
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_h100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1,2,3", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.6.6.post1_20250731"   # old -- "v0.6.6.post1_20250430"
    },
    {
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 2
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-70b-qtz-${local.region_codes[var.region_default]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-qtz-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 45
      cpu_alloc_min                    = 45
      memory_alloc_max                 = "420Gi"
      memory_alloc_min                 = "420Gi"
      set_shm_to_memory                = true
      number_of_replicas               = var.environment == "prod" ? 0 : 0
      number_of_replicas_spot_capacity = var.environment == "prod" ? 0 : 0
      spot_capacity_compute_class      = module.container-cluster-default-flex-start-a3-highgpu-2g-pool-config[0].compute_class_name
      container_command_override = ["./start_vllm_h100_quantized.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1,2,3", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260410"
      # target a different node pool with less GPUs per node since the model is quantized and can fit on 2 gpus instead of 4
      gpu_nodepool              = "a3-highgpu-2g-flex-pool"
      enable_deep_health_check         = true
    },
    {
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "llama-3-8b-instruct",
      model_config                     = "this-config-does-not-exist.json", # MP: I don't think this used
      gpu_accelerator_type             = "nvidia-a100-80gb",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-8b-${local.region_codes[var.region_default]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-8b-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 8
      cpu_alloc_min                    = 8
      memory_alloc_max                 = "120Gi"
      memory_alloc_min                 = "120Gi"
      set_shm_to_memory                = true
      # Cost optimization (2026-04): reduced from 2 -> 1 replica.
      # Verified via vLLM metrics: GPU KV cache usage peaks at 0.7% with 2 replicas;
      # us-west1 has 2 additional replicas of the same model for redundancy.
      number_of_replicas               = var.environment == "prod" ? 1 : 0
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = module.container-cluster-default-flex-start-a3-highgpu-2g-pool-config[0].compute_class_name
      container_command_override = ["./start_vllm_llama8b_1xa100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0", # gpus
        "llama-3.1-8b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260410"   # old -- "v0.10.1.1_20260226"
      gpu_nodepool              = "gke-default-a2-ultragpu-2g-pool"
      enable_deep_health_check         = true
    },
    {
      # Qwen 3.5 4B inference service (spot-capacity only).
      # Prereq: weights at gs://spiffy-llm-inference-service-<env>/qwen-3.5-4b/ before applying.
      # K8s deployment names: llm-inference-svc-qwen-3-5-4b-<region> (regular, replicas=0)
      #                       llm-inference-svc-qwen-3-5-4b-<region>-spot-cap (spot, replicas=1)
      # NOTE: the submodule filters to enabled services then count-indexes them, so
      # inserting an enabled service BEFORE an existing one shifts indices and forces
      # replacement of live services. Only APPEND new enabled entries at the end of
      # this list (see the MIG entries below) to keep existing indices stable.
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "qwen-3.5-4b",
      model_config                     = "this-config-does-not-exist.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 1
      # K8s resource names disallow dots; use "qwen-3-5-4b" instead of "qwen-3.5-4b".
      service_name_suffix              = "qwen-3-5-4b-${local.region_codes[var.region_default]}"
      service_fqdn                     = "inference-qwen-3-5-4b-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 16
      cpu_alloc_min                    = 16
      memory_alloc_max                 = "160Gi"
      memory_alloc_min                 = "160Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 0
      number_of_replicas_spot_capacity = var.environment == "prod" ? 1 : 0
      spot_capacity_compute_class      = module.container-cluster-default-flex-start-a3-highgpu-1g-pool-config[0].compute_class_name
      container_command_override = ["./start_llm_v021.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0", # gpus
        "qwen-3.5-4b", # model folder
        "qwen-3.5-4b", # served model name
        "1" # tensor parallel size
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.21.0_20260522"
      gpu_nodepool              = null # spot-cap only; uses a3-highgpu-1g compute class
      # Qwen is a reasoning model: the deep-health-check generates up to 1000 tokens,
      # exceeding the 10s readiness probe timeout, so it never becomes Ready. Fall back
      # to vLLM's native /health probe (fast). See llama-3-8b which stays on deep-health.
      enable_deep_health_check         = false
    },
    {
      enabled                          = false
      model_name                       = "gemma-3-27b-it",
      model_config                     = "this-config-does-not-exist.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 2
      service_name_suffix              = "gemma-3-27b-${local.region_codes[var.region_default]}"
      service_fqdn                     = "inference-gemma-3-27b-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 45
      cpu_alloc_min                    = 45
      memory_alloc_max                 = "420Gi"
      memory_alloc_min                 = "420Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 0
      number_of_replicas_spot_capacity = contains(["dev", "prod"], var.environment) ? 1 : 0
      spot_capacity_compute_class      = module.container-cluster-default-flex-start-a3-highgpu-2g-pool-config[0].compute_class_name
      container_command_override       = ["./start_llm.sh"]
      container_command_args_override  = [
        "/data/llm-service",
        "/data/ssd",
        "0,1",
        "gemma-3-27b-it",
        "gemma-3-27b-it",
        "2"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.11.0_20251210"
      gpu_nodepool              = "gke-default-a3-highgpu-8g-pool"
    },
    {
      # ---- MIG demo: two models sharing ONE physical H100 -------------------
      # Qwen3-8B on a single H100 MIG slice (3g.40gb / ~40GB) -- slice 1 of 2.
      # Co-located with the llama-3-1-8b-mig service below on the same physical
      # H100 via node pool gke-default-a3-highgpu-1g-mig-pool (2x 3g.40gb).
      # Both Pods request nvidia.com/gpu: 1 and land on the same node.
      # Prereqs (Pod crashloops without them):
      #   1. Weights at gs://spiffy-llm-inference-service-<env>/qwen3-8b/base/
      #   2. Image v0.21.0_20260616 built+pushed (adds start_vllm_mig_3g40gb.sh)
      #      via scripts/vllm/build-docker_v021.sh
      # cpu/mem are half-node so both MIG Pods fit on one a3-highgpu-1g (26 vCPU / 234Gi).
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "qwen3-8b",
      model_config                     = "this-config-does-not-exist.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 1
      service_name_suffix              = "qwen3-8b-mig-${local.region_codes[var.region_default]}"
      service_fqdn                     = "inference-qwen3-8b-mig-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 10
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "100Gi"
      memory_alloc_min                 = "100Gi"
      set_shm_to_memory                = true
      number_of_replicas               = var.environment == "prod" ? 1 : 0
      number_of_replicas_spot_capacity = null
      spot_capacity_compute_class      = null
      container_command_override       = ["./start_vllm_mig_3g40gb.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd",         # ssd path
        "0",                 # cuda visible devices (single MIG slice in the Pod)
        "qwen3-8b",          # model folder
        "qwen3-8b",          # served model name
      ]
      additional_container_command_args = []
      docker_image_override             = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override         = "v0.21.0_20260616"
      gpu_nodepool                      = "gke-default-a3-highgpu-1g-mig-pool"
      # Reasoning-capable: native /health probe (deep check can exceed timeout).
      enable_deep_health_check = false
    },
    {
      # MIG demo slice 2 of 2: Llama-3.1-8B-Instruct sharing the same H100 as
      # qwen3-8b-mig above. Weights already exist in the bucket under
      # llama-3.1-8b-instruct/ (reused by the existing llama-3-8b service).
      # Prereq: image v0.21.0_20260616 built+pushed (adds start_vllm_mig_3g40gb.sh).
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "llama-3.1-8b-instruct",
      model_config                     = "this-config-does-not-exist.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 1
      service_name_suffix              = "llama-3-1-8b-mig-${local.region_codes[var.region_default]}"
      service_fqdn                     = "inference-llama-3-1-8b-mig-${local.region_codes[var.region_default]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 10
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "100Gi"
      memory_alloc_min                 = "100Gi"
      set_shm_to_memory                = true
      number_of_replicas               = var.environment == "prod" ? 1 : 0
      number_of_replicas_spot_capacity = null
      spot_capacity_compute_class      = null
      container_command_override       = ["./start_vllm_mig_3g40gb.sh"]
      container_command_args_override = [
        "/data/llm-service",     # source path
        "/data/ssd",             # ssd path
        "0",                     # cuda visible devices (single MIG slice in the Pod)
        "llama-3.1-8b-instruct", # model folder
        "llama-3.1-8b-instruct", # served model name
      ]
      additional_container_command_args = []
      docker_image_override             = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override         = "v0.21.0_20260616"
      gpu_nodepool                      = "gke-default-a3-highgpu-1g-mig-pool"
      enable_deep_health_check          = false
    },
  ]

  text_generation_service_config = [
    {
      enabled                          = true
      model_name                       = "Snowflake/snowflake-arctic-embed-m-v1.5", # "Snowflake/snowflake-arctic-embed-m"
      model_config                     = "",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "textembed-default" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "text-embed-default.${local.domain_name_suffix}"
      cpu_alloc_max                    = 3
      cpu_alloc_min                    = 3
      memory_alloc_max                 = "12Gi"
      memory_alloc_min                 = "12Gi"
      set_shm_to_memory                = true
      # Cost optimization (2026-04): reduced from 2 -> 1 replica in prod.
      # Embedding model (snowflake-arctic-embed-m-v1.5, ~137M params) runs
      # on a g2-standard-8 / 1x L4 node. Dropping to 1 replica frees one
      # NAP g2-standard-8 node (~$600/mo). Revisit if text-embed-default
      # P95 latency regresses.
      number_of_replicas               = var.environment == "prod" ? 1 : 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      docker_image_override            = "ghcr.io/huggingface/text-embeddings-inference"
      docker_image_tag_override        = "89-1.7"
    },
    {
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "Snowflake/snowflake-arctic-embed-m-v1.5", # "Snowflake/snowflake-arctic-embed-m"
      model_config                     = "",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "textembed-search-idx-default" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "text-embed-search-idx-default.${local.domain_name_suffix}"
      cpu_alloc_max                    = 3
      cpu_alloc_min                    = 3
      memory_alloc_max                 = "12Gi"
      memory_alloc_min                 = "12Gi"
      set_shm_to_memory                = true
      number_of_replicas               = var.environment == "prod" ? 1 : 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      docker_image_override            = "ghcr.io/huggingface/text-embeddings-inference"
      docker_image_tag_override        = "89-1.7"
    },
  ]
}

moved {
  from = module.llm-inference-service-set-us-west1
  to   = module.llm-inference-service-set-secondary-region
}

module "llm-inference-service-set-secondary-region" {

  count = 1 # with prod GKE cluster provider
  depends_on = [
    module.container-cluster-secondary-region-config,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  source                = "./services/llm-inference-set"
  region_codes          = local.region_codes
  gke_cluster_name      = module.container-cluster-secondary-region[0].cluster_name
  gke_cluster_region    = module.container-cluster-secondary-region[0].cluster_region
  gke_cluster_namespace = local.gke_workload_namespace_for_llm_apps
  gke_cluster_subnet    = module.container-cluster-secondary-region[0].cluster_subnet
  docker_image          = module.git-repo-vllm[0].docker_image
  docker_image_tag      = var.environment == "prod" ? module.git-repo-vllm[0].docker_image_prod_tag : module.git-repo-vllm[0].docker_image_latest_tag
  environment           = var.environment
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-secondary-region
  }
  project_id                     = var.project_id
  project_number                 = google_project.deployment-project.number
  vpc_name                       = google_compute_network.vpc-deployment.name
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  service_set_name        = var.environment == "prod" ? "llm-inference-svc" : "llm-inference-service"
  service_gcs_bucket_name = google_storage_bucket.llm-inference-service-gcs-bucket.name
  inference_service_config = [
    {
      enabled                          = false
      model_name                       = "llama-2-7b-base",
      model_config                     = "vllm_7b_1x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "na-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 5
      cpu_alloc_min                    = 2
      memory_alloc_max                 = "80Gi"
      memory_alloc_min                 = "2Gi"
      set_shm_to_memory                = true
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-2-7b-chat",
      model_config                     = "vllm_7b_1x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "chat-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-chat-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 5
      cpu_alloc_min                    = 2
      memory_alloc_max                 = "80Gi"
      memory_alloc_min                 = "2Gi"
      set_shm_to_memory                = true
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-2-70b-chat",
      model_config                     = "vllm_70b_8x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 8
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "70b-chat-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-70b-chat-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 15
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "320Gi"
      memory_alloc_min                 = "320Gi"
      set_shm_to_memory                = true
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-2-70b-chat",
      model_config                     = "vllm_70b_8x24gb.json",
      gpu_accelerator_type             = "nvidia-l4",
      gpu_accelerator_count            = 8
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "70b-chat-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-70b-chat-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 15
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "320Gi"
      memory_alloc_min                 = "320Gi"
      set_shm_to_memory                = true
      container_command_override = []
      container_command_args_override = []
      additional_container_command_args = []
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      docker_image_override            = null
      docker_image_tag_override        = null
    },
    {
      enabled                          = false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 4
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix              = "llama-3-70b-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 90
      cpu_alloc_min                    = 90
      memory_alloc_max                 = "840Gi"
      memory_alloc_min                 = "840Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 2
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_h100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1,2,3", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.6.6.post1_20250731"   # old -- "v0.6.6.post1_20250430"
    },
    {
      enabled                          = var.environment == "dev" ? true : false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-a100-80gb",
      gpu_accelerator_count            = 2
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-70b-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 10
      cpu_alloc_min                    = 10
      memory_alloc_max                 = "310Gi"
      memory_alloc_min                 = "310Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_a100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260410" # old: v0.10.1.1_20260226
      gpu_nodepool              = "gke-default-a2-ultragpu-2g-pool"
      enable_deep_health_check         = true
    },
    {
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 4
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-70b-qa-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-qa-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 90
      cpu_alloc_min                    = 90
      memory_alloc_max                 = "840Gi"
      memory_alloc_min                 = "840Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 0
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class = null
      # Uncomment this to override the default container command args (ex: by pass start_vllm entrypoint)
      container_command_override = ["./start_vllm_h100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1,2,3", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.6.6.post1_20250731"   # old -- "v0.6.6.post1_20250430"
    },
    {
      enabled                          = var.environment == "dev" ? true : false
      model_name                       = "llama-3-8b-instruct",
      model_config                     = "this-config-does-not-exist.json", # MP: I don't think this used
      gpu_accelerator_type             = "nvidia-a100-80gb",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-8b-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-8b-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 4
      cpu_alloc_min                    = 4
      memory_alloc_max                 = "120Gi"
      memory_alloc_min                 = "120Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 1
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_llama8b_1xa100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0", # gpu
        "llama-3.1-8b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260410"  # old: v0.10.1.1_20260226
      gpu_nodepool              = "gke-default-a2-ultragpu-1g-pool"
      enable_deep_health_check         = true
    },
    {
      enabled                          = false                              # spot
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 2
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-70b-qtz-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-qtz-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 45
      cpu_alloc_min                    = 45
      memory_alloc_max                 = "420Gi"
      memory_alloc_min                 = "420Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 0
      number_of_replicas_spot_capacity = 1 # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = module.container-cluster-secondary-flex-start-a3-highgpu-2g-pool-config[0].compute_class_name
      container_command_override = ["./start_vllm_h100_quantized.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260410"
    },
    {
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "llama-3-70b-instruct",
      model_config                     = "vllm_70b_4x40gb.json",
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 2
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix              = "llama-3-70b-qtz-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-70b-qtz-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 45
      cpu_alloc_min                    = 45
      memory_alloc_max                 = "420Gi"
      memory_alloc_min                 = "420Gi"
      set_shm_to_memory                = true
      # Cost optimization (2026-04): reduced from 3 -> 2 replicas.
      # Verified via vLLM metrics on us-west1 pods: GPU KV cache usage stays
      # at 0.1-4.8% and "Running: 0 reqs" dominates the log output, so 3
      # replicas are materially over-provisioned. us-central1 flex-start
      # a3-highgpu-2g node provides additional spot-capacity fallback.
      # Note: the 8x H100 node in us-west1 stays up because the remaining
      # 2 replicas (4x H100) plus 2x llama-3-8b (2x H100) still fill 6/8
      # H100s. Follow-up: consider moving 8b off to smaller node type to
      # downsize this node to a3-highgpu-4g.
      number_of_replicas               = 2
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_h100_quantized.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0,1", # gpus
        "llama-3.1-70b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260505" # bumped to match the image deployed out-of-band by CD; was v0.17.1_20260410
      gpu_nodepool              = "gke-default-a3-highgpu-8g-pool"
      enable_deep_health_check         = true
    },
    {
      enabled                          = var.environment == "prod" ? true : false
      model_name                       = "llama-3-8b-instruct",
      model_config                     = "this-config-does-not-exist.json", # MP: I don't think this used
      gpu_accelerator_type             = "nvidia-h100-80gb",
      gpu_accelerator_count            = 1
      # Each pod that is unique needs a unique name in kubernetes.
      # So the pod name just becomes ""service_set_name + service_name_suffix"
      # This is an internal detail to GKE and has no functional consequences
      # It can be made a random string using terraform but made it.
      # configurable to make them more human readable in the GCP console.
      service_name_suffix = "llama-3-8b-${local.region_codes[var.region_secondary]}" # this must be updated to be unique if there are multiple instances running in different regions
      service_fqdn                     = "inference-llama-3-8b-${local.region_codes[var.region_secondary]}.${local.domain_name_suffix}"
      cpu_alloc_max                    = 23
      cpu_alloc_min                    = 23
      memory_alloc_max                 = "210Gi"
      memory_alloc_min                 = "210Gi"
      set_shm_to_memory                = true
      number_of_replicas               = 2
      number_of_replicas_spot_capacity = null # leave it null to not create the spot cap deployment
      spot_capacity_compute_class      = null
      container_command_override = ["./start_vllm_llama8b_1xa100.sh"]
      container_command_args_override = [
        "/data/llm-service", # source path
        "/data/ssd", # ssd path
        "0", # gpu
        "llama-3.1-8b-instruct"
      ]
      additional_container_command_args = []
      docker_image_override     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
      docker_image_tag_override = "v0.17.1_20260410"   # old -- "v0.10.1.1_20260226"
      gpu_nodepool              = "gke-default-a3-highgpu-8g-pool"
      enable_deep_health_check         = true
    },
  ]
}

module "nwac-data-api" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  source             = "./services/nwac-data-api"
  count = 0 # disabled
  service_name       = "nwac-data-api"
  environment        = var.environment
  project_id         = var.project_id
  docker_image       = module.git-repo-nwac[0].docker_image
  docker_image_tag   = var.environment == "prod" ? module.git-repo-nwac[0].docker_image_prod_tag : module.git-repo-nwac[0].docker_image_latest_tag
  region             = var.region_default
  vpc_name           = google_compute_network.vpc-deployment.name
  subnet_name        = google_compute_subnetwork.deployment-subnet-dmz.name
  domain_name_public = "nwac-data.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site          = var.datadog_site
  datadog_trace_enabled = true
}

module "elastic-search-default-cluster" {
  source       = "./services/elasticsearch"
  cluster_name = "spiffy-default-deployment-${var.environment}"
  environment  = var.environment
  project_id   = var.project_id
  region       = var.elastic_cloud_gcp_region # gcp-us-west1 or gcp-us-central1
}

module "segment-intake-service" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                       = "./services/segment-intake"
  count                        = local.segment_webhooks_ingest_enabled ? 1 : 0
  service_name                 = "segment-intake"
  environment                  = var.environment
  gke_cluster_name             = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace        = local.gke_workload_namespace_for_services_apps
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  project_id                   = var.project_id
  docker_image                 = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag             = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region                       = var.region_default
  subnet                       = google_compute_subnetwork.deployment-subnet-app.name
  vpc_name                     = google_compute_network.vpc-deployment.name
  domain_name_public           = "segment-intake.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site             = var.datadog_site
  datadog_trace_enabled    = false
  database_connection_name = module.main-db.instance_connection_name
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  project_number           = google_project.deployment-project.number
  cloudsql_instance_name   = module.main-db.instance_name
}

module "segment-streams-processor" {
  depends_on = [
    google_project_service.all,
    module.segment-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/segment-streams-processor"
  count                          = local.segment_webhooks_ingest_enabled ? 1 : 0
  service_name                   = "segment-streams-processor"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                           = var.region_default
  segment_intake_topic_id          = module.segment-intake-service[0].segment_intake_topic_id
  vpc_name                         = google_compute_network.vpc-deployment.name
  persistence_bigquery_table_id    = "${var.project_id}.${module.bigquery_datatable_for_segment_cdp_streams[0].dataset_id}.${module.bigquery_datatable_for_segment_cdp_streams[0].table_id}"
  cdp_streams_bigtable_events_table_ids = [google_bigtable_table.cdp-streams-bigtable-table-user-events.name, google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name]
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
  cloudsql_instance_name           = module.main-db.instance_name
  database_connection_name         = module.main-db.instance_connection_name
}

module "rudderstack-intake-service" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                = "./services/rudderstack-intake"
  count                 = local.rudderstack_webhooks_ingest_enabled ? 1 : 0
  service_name          = "rudderstack-intake"
  gke_cluster_name      = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace = local.gke_workload_namespace_for_services_apps
  environment           = var.environment
  project_id            = google_project.deployment-project.project_id
  project_number        = google_project.deployment-project.number
  docker_image          = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag      = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region                = var.region_default
  subnet                = google_compute_subnetwork.deployment-subnet-app.name
  vpc_name              = google_compute_network.vpc-deployment.name
  domain_name_public    = "rudderstack-intake.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site                 = var.datadog_site
  datadog_trace_enabled        = false
  database_connection_name     = module.main-db.instance_connection_name
  redis_host                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  cloudsql_instance_name       = module.main-db.instance_name
}

module "rudderstack-streams-processor" {
  depends_on = [
    google_project_service.all,
    module.rudderstack-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/rudderstack-streams-processor"
  count                          = local.rudderstack_webhooks_ingest_enabled ? 1 : 0
  service_name                   = "rudderstack-streams-processor"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                           = var.region_default
  rudderstack_intake_topic_id      = module.rudderstack-intake-service[0].rudderstack_intake_topic_id
  vpc_name                         = google_compute_network.vpc-deployment.name
  persistence_bigquery_table_id    = "${var.project_id}.${module.bigquery_datatable_for_rudderstack_cdp_streams[0].dataset_id}.${module.bigquery_datatable_for_rudderstack_cdp_streams[0].table_id}"
  cdp_streams_bigtable_events_table_ids = [google_bigtable_table.cdp-streams-bigtable-table-user-events.name, google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name]
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
  cloudsql_instance_name           = module.main-db.instance_name
  database_connection_name         = module.main-db.instance_connection_name
}

module "simondata-intake-service" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                = "./services/simondata-intake"
  count                 = local.simondata_webhooks_ingest_enabled ? 1 : 0
  service_name          = "simondata-intake"
  gke_cluster_name      = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace = local.gke_workload_namespace_for_services_apps
  environment           = var.environment
  project_id            = google_project.deployment-project.project_id
  project_number   = google_project.deployment-project.number
  docker_image     = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region           = var.region_default
  subnet           = google_compute_subnetwork.deployment-subnet-app.name
  vpc_name         = google_compute_network.vpc-deployment.name
  domain_name_public    = "simondata-intake.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site                 = var.datadog_site
  datadog_trace_enabled        = false
  database_connection_name     = module.main-db.instance_connection_name
  redis_host                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  cloudsql_instance_name       = module.main-db.instance_name
}

module "simondata-streams-processor" {
  depends_on = [
    google_project_service.all,
    module.simondata-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/simondata-streams-processor"
  count                          = local.simondata_webhooks_ingest_enabled ? 1 : 0
  service_name                   = "simondata-streams-processor"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                           = var.region_default
  simondata_intake_topic_id        = module.simondata-intake-service[0].simondata_intake_topic_id
  vpc_name                         = google_compute_network.vpc-deployment.name
  persistence_bigquery_table_id    = "${var.project_id}.${module.bigquery_datatable_for_simondata_cdp_streams[0].dataset_id}.${module.bigquery_datatable_for_simondata_cdp_streams[0].table_id}"
  cdp_streams_bigtable_events_table_ids = [google_bigtable_table.cdp-streams-bigtable-table-user-events.name, google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name]
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
  cloudsql_instance_name           = module.main-db.instance_name
  database_connection_name         = module.main-db.instance_connection_name
}

module "shopify-webhooks-intake-service" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                = "./services/shopify-intake"
  count                 = local.shopfiy_webhooks_ingest_enabled ? 1 : 0
  service_name          = "shopify-intake"
  gke_cluster_name      = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace = local.gke_workload_namespace_for_services_apps
  environment           = var.environment
  project_id       = google_project.deployment-project.project_id
  project_number   = google_project.deployment-project.number
  docker_image     = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  region           = var.region_default
  subnet           = google_compute_subnetwork.deployment-subnet-app.name
  vpc_name              = google_compute_network.vpc-deployment.name
  domain_name_public    = "shopify-intake.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site                 = var.datadog_site
  datadog_trace_enabled        = false
  database_connection_name     = module.main-db.instance_connection_name
  redis_host                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                   = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  cloudsql_instance_name       = module.main-db.instance_name
}

module "shopify-streams-processor" {
  depends_on = [
    google_project_service.all,
    module.shopify-webhooks-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/shopify-streams-processor"
  count                          = local.shopfiy_webhooks_ingest_enabled ? 1 : 0
  service_name                   = "shopify-streams-processor"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                           = var.region_default
  shopify_intake_topic_id          = module.shopify-webhooks-intake-service[0].shopify_intake_topic_id
  vpc_name                         = google_compute_network.vpc-deployment.name
  persistence_bigquery_table_id    = "${var.project_id}.${module.bigquery_datatable_for_shopify_cdp_streams[0].dataset_id}.${module.bigquery_datatable_for_shopify_cdp_streams[0].table_id}"
  cdp_streams_bigtable_events_table_ids = [google_bigtable_table.cdp-streams-bigtable-table-user-events.name, google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name]
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
  cloudsql_instance_name           = module.main-db.instance_name
  database_connection_name         = module.main-db.instance_connection_name
}

module "chat-sessions-service" {
  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
    module.container-cluster-default-config,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/chat-sessions"
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name                   = "chat-sessions"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id               = google_project.deployment-project.project_id
  project_number           = google_project.deployment-project.number
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                   = var.region_default
  vpc_name                 = google_compute_network.vpc-deployment.name
  cloudsql_instance_name   = module.main-db.instance_name
  database_connection_name = module.main-db.instance_connection_name
}

module "shopify-app" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  count            = 1
  service_name     = "shopify-app"
  source           = "./services/shopify-app"
  environment      = var.environment
  project_id       = var.project_id
  docker_image     = module.git-repo-for-shopify-app[0].docker_image
  docker_image_tag = var.environment == "prod" ? module.git-repo-for-shopify-app[0].docker_image_prod_tag : module.git-repo-for-shopify-app[0].docker_image_latest_tag
  region           = var.region_default
  vpc_name         = google_compute_network.vpc-deployment.name
  subnet_name      = google_compute_subnetwork.deployment-subnet-dmz.name
  domain_name_public = "shop-app.${local.domain_name_suffix}" # shopify doesn't allow "shopify" in the domain name. sigh.
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site          = var.datadog_site
  datadog_trace_enabled = true
}

module "cdc-main-db" {
  depends_on = [
    google_project_service.all,
    google_storage_bucket.cdc-streams-data-gcs-bucket,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  count                        = var.environment == "dev" ? 1 : 1
  service_name                 = "cdc-main-db"
  source                       = "./services/cdc"
  environment                  = var.environment
  subnet                       = google_compute_subnetwork.deployment-subnet-app.name
  project_id                   = var.project_id
  managed_ssl_certificate_name = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  cloudsql_instance_name       = module.main-db.instance_name
  cluster_namespace            = local.gke_workload_namespace_for_services_apps
  cpu_alloc_max                = 1
  cpu_alloc_min                = 1
  memory_alloc_max             = "1Gi"
  memory_alloc_min             = "1Gi"
  private_dns_zone_name        = google_dns_managed_zone.private-zone.name
  project_number               = google_project.deployment-project.number
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  service_fqdn                   = "cdc-main-db.${local.domain_name_suffix}"
  service_gcs_bucket_name        = google_storage_bucket.cdc-streams-data-gcs-bucket.name
  database_connection_name       = module.main-db.instance_connection_name
  data_source                    = local.cdc_datasource_main_db
  region                         = var.region_default
}

module "cdc-streams-processor" {
  depends_on = [
    google_project_service.all,
    module.segment-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  region                         = var.region_default
  source                         = "./services/cdc-streams-processor"
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name                   = "cdc-streams-processor"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  project_id                     = google_project.deployment-project.project_id
  project_number                 = google_project.deployment-project.number
  persistence_bigquery_table_id  = "${var.project_id}.${module.bigquery_datatable_for_segment_cdp_streams[0].dataset_id}.${module.bigquery_datatable_for_segment_cdp_streams[0].table_id}"
  cloudsql_instance_name         = module.main-db.instance_name
  database_connection_name       = module.main-db.instance_connection_name
}

moved {
  from = module.model-train-job
  to   = module.model-train-job-prototype
}

module "model-train-job-prototype" {
  depends_on = [
    google_project_service.all,
    module.segment-intake-service,
    module.gke-dws-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-gke-dws-cluster-default
    kubectl    = kubectl.kubectl-provider-for-gke-dws-cluster-default
  }
  source                         = "./services/training-job-prototype"
  count = contains(["dev"], var.environment) ? 1 : 0 # Disabled
  service_name                   = "model-train-job"
  environment                    = var.environment
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  project_id                     = google_project.deployment-project.project_id
  project_number                 = google_project.deployment-project.number
  database_connection_name       = module.main-db.instance_connection_name
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  service_gcs_bucket_name        = google_storage_bucket.spiffy-train.name
  additional_service_gcs_bucket_names = [google_storage_bucket.llm-inference-service-gcs-bucket.name]
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  cloudsql_instance_name = module.main-db.instance_name
  datadog_api_key        = data.google_secret_manager_secret_version.datadog_api_key.secret_data
  datadog_app_key        = data.google_secret_manager_secret_version.datadog_app_key.secret_data
  datadog_site           = var.datadog_site
}

module "test-job-prototype" {
  depends_on = [
    google_project_service.all,
    module.segment-intake-service,
    module.gke-dws-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-gke-dws-cluster-default
    kubectl    = kubectl.kubectl-provider-for-gke-dws-cluster-default
  }
  source                         = "./services/testing-job-prototype"
  count = contains(["dev"], var.environment) ? 1 : 0 # Disabled
  service_name                   = "test-job-1"
  environment                    = var.environment
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  project_id                     = google_project.deployment-project.project_id
  project_number                 = google_project.deployment-project.number
  database_connection_name       = module.main-db.instance_connection_name
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  service_gcs_bucket_name        = google_storage_bucket.llm-inference-service-gcs-bucket.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  cloudsql_instance_name = module.main-db.instance_name
  datadog_api_key = data.google_secret_manager_secret_version.datadog_api_key.secret_data
  datadog_app_key = data.google_secret_manager_secret_version.datadog_app_key.secret_data
  datadog_site = var.datadog_site
  container_command_override = ["./start_vllm_h100_quantized.sh"]
  container_command_args_override = [
    "/data/llm-service", # source path
    "/data/ssd", # ssd path
    "0,1,2,3", # gpus
    "llama-3.1-70b-instruct"
  ]
  cpu_alloc_max                    = 45
  cpu_alloc_min                    = 45
  memory_alloc_max                 = "420Gi"
  memory_alloc_min                 = "420Gi"
  gpu_accelerator_type             = "nvidia-h100-80gb"
  gpu_accelerator_count            = 2
  docker_image                     = "us-docker.pkg.dev/spiffy-prod/spiffy/vllm-openai"
  docker_image_tag                 = "v0.17.1_20260410"
  target_node_pool_name            = "gke-default-a3-highgpu-2g-dws-pool"
  enable_deep_health_check         = true
}

module "model-training-activities" {
  depends_on = [
    google_project_service.all,
    module.shopify-webhooks-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/model-training-activities"
  count = contains(["dev", "prod"], var.environment) && var.gke_dws_default_cluster_enabled ? 1 : 0 # Only in dev
  service_name                   = "model-training-activities"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id               = google_project.deployment-project.project_id
  project_number           = google_project.deployment-project.number
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                   = var.region_default
  region_default           = var.region_default
  vpc_name                 = google_compute_network.vpc-deployment.name
  cloudsql_instance_name   = module.main-db.instance_name
  database_connection_name = module.main-db.instance_connection_name
  gke_dws_cluster_name     = module.gke-dws-cluster-default[0].cluster_name
  gke_dws_cluster_region   = module.gke-dws-cluster-default[0].cluster_region
  gke_default_cluster_name     = module.container-cluster-default[0].cluster_name
  gke_default_cluster_region   = module.container-cluster-default[0].cluster_region
  gke_secondary_cluster_name   = module.container-cluster-secondary-region[0].cluster_name
  gke_secondary_cluster_region = module.container-cluster-secondary-region[0].cluster_region
  temporal_host            = var.temporal_host
  datadog_site             = var.datadog_site
  team                     = "model-finetuning"
  chapter                  = "ml"
  gke_k8_inference_namespace   = "apps-llm-ns"
}

# evaluation-worker deployment already exists in the cluster but is not yet in
# Terraform state (bootstrapped before Terraform was managing it). Import so that
# subsequent plans show no diff rather than "will be created".
import {
  to = module.evaluation-worker[0].module.service.kubernetes_deployment_v1.kubernetes_app_deployment
  id = "apps-services-ns/evaluation-worker"
}

import {
  to = module.evaluation-worker[0].module.service.kubernetes_service_v1.service_cluster_ip
  id = "apps-services-ns/evaluation-worker-grpc-server"
}

module "evaluation-worker" {
  depends_on = [
    google_project_service.all,
    module.container-cluster-default-config,
    data.google_container_cluster.container-cluster-default-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                   = "./services/evaluation-worker"
  count                    = contains(["dev", "prod"], var.environment) ? 1 : 0
  service_name             = "evaluation-worker"
  docker_image             = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag         = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment              = var.environment
  gke_cluster_name         = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace    = local.gke_workload_namespace_for_services_apps
  project_id               = google_project.deployment-project.project_id
  project_number           = google_project.deployment-project.number
  region                   = var.region_default
  cloudsql_instance_name   = module.main-db.instance_name
  database_connection_name = module.main-db.instance_connection_name
  temporal_host            = var.temporal_host
  datadog_site             = var.datadog_site
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  vpc_name                 = google_compute_network.vpc-deployment.name
  team                     = "engineering"
  chapter                  = "backend"
}

module "faq-scrape-worker" {
  depends_on = [
    google_project_service.all,
    module.container-cluster-default-config,
    data.google_container_cluster.container-cluster-default-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                   = "./services/faq-scrape-worker"
  count                    = contains(["dev", "prod"], var.environment) ? 1 : 0
  service_name             = "faq-scrape-worker"
  docker_image             = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag         = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment              = var.environment
  gke_cluster_name         = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace    = local.gke_workload_namespace_for_services_apps
  project_id               = google_project.deployment-project.project_id
  project_number           = google_project.deployment-project.number
  region                   = var.region_default
  cloudsql_instance_name   = module.main-db.instance_name
  database_connection_name = module.main-db.instance_connection_name
  temporal_host            = var.temporal_host
  datadog_site             = var.datadog_site
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  vpc_name                 = google_compute_network.vpc-deployment.name
  team                     = "engineering"
  chapter                  = "backend"
}

module "analytics-events-etl-worker" {
  depends_on = [
    google_project_service.all,
    module.container-cluster-default-config,
    data.google_container_cluster.container-cluster-default-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                = "./services/analytics-events-etl-worker"
  count                 = contains(["dev", "prod"], var.environment) ? 1 : 0
  service_name          = "analytics-events-etl-worker"
  docker_image          = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag      = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment           = var.environment
  gke_cluster_namespace = local.gke_workload_namespace_for_services_apps
  project_id            = google_project.deployment-project.project_id
  project_number        = google_project.deployment-project.number
  region                = var.region_default
  temporal_host         = var.temporal_host
  datadog_site          = var.datadog_site
  team                  = "engineering"
  chapter               = "backend"
}

module "organizations" {
  depends_on = [
    google_project_service.all,
    module.shopify-webhooks-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/organizations"
  count = contains(["dev", "prod"], var.environment) && var.gke_dws_default_cluster_enabled ? 1 : 0 # Only in dev, prod
  service_name                   = "organizations"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id               = google_project.deployment-project.project_id
  project_number           = google_project.deployment-project.number
  redis_host               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port               = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                   = var.region_default
  region_default           = var.region_default
  vpc_name                 = google_compute_network.vpc-deployment.name
  cloudsql_instance_name   = module.main-db.instance_name
  database_connection_name = module.main-db.instance_connection_name
  gke_dws_cluster_name     = module.gke-dws-cluster-default[0].cluster_name
  gke_dws_cluster_region   = module.gke-dws-cluster-default[0].cluster_region
  temporal_host            = var.temporal_host
  datadog_site             = var.datadog_site
  datadog_api_key          = var.datadog_api_key
  datadog_app_key          = var.datadog_app_key
}

module "analytics-streams-processor" {
  depends_on = [
    google_project_service.all,
    module.shopify-webhooks-intake-service,
    module.container-cluster-default-config,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data,
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source                         = "./services/analytics-streams-processor"
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name                   = "analytics-streams-processor"
  docker_image                   = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag               = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  environment                    = var.environment
  gke_cluster_name               = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace          = local.gke_workload_namespace_for_services_apps
  service_directory_namespace_id = google_service_directory_namespace.service_directory_namespace_backend_apps.id
  managed_ssl_certificate_name   = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  private_dns_zone_name          = google_dns_managed_zone.private-zone.name
  public_dns_zone_name = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  project_id                       = google_project.deployment-project.project_id
  project_number                   = google_project.deployment-project.number
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  region                           = var.region_default
  analytics_intake_topic_id        = module.analytics-gateway[0].intake_topic_id
  vpc_name                         = google_compute_network.vpc-deployment.name
  cloudsql_instance_name           = module.main-db.instance_name
  database_connection_name         = module.main-db.instance_connection_name
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
}
