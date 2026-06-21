module "commerce-api" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source       = "./services/commerce-api"
  region       = var.region_default
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name = "commerce-api"
  environment  = var.environment
  project_id   = var.project_id
  subnet       = google_compute_subnetwork.deployment-subnet-app.name
  docker_image       = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag   = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  domain_name_public = "commerce-api.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site                     = var.datadog_site
  datadog_trace_enabled            = true
  database_connection_name         = module.main-db.instance_connection_name
  datastore_id                     = google_firestore_database.spiffy-annotations-store.id
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  chat_sessions_topic_id           = module.chat-sessions-service[0].chat_sessions_topic_id
  cdp_streams_bigtable_events_table_ids = [google_bigtable_table.cdp-streams-bigtable-table-user-events.name, google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name]
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
  gke_cluster_name                 = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace            = local.gke_workload_namespace_for_services_apps
  cloudsql_instance_name           = module.main-db.instance_name
  managed_ssl_certificate_name     = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  project_number                   = google_project.deployment-project.number
  text_embed_endpoint_url          = var.text_embed_endpoint_url
}

module "analytics-gateway" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data
  ]
  providers = {
    kubernetes = kubernetes.kubernetes-provider-for-container-cluster-default
  }
  source             = "./services/analytics-gateway"
  region             = var.region_default
  subnet             = google_compute_subnetwork.deployment-subnet-app.name
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name       = "analytics-gateway"
  environment        = var.environment
  project_id         = var.project_id
  docker_image       = module.git-repo-pymono-for-all-services[0].docker_image
  docker_image_tag   = var.environment == "prod" ? module.git-repo-pymono-for-all-services[0].docker_image_prod_tag : module.git-repo-pymono-for-all-services[0].docker_image_latest_tag
  domain_name_public = "analytics-gateway.${local.domain_name_suffix}"
  dns_zone_name_public = {
    name     = local.public_dns_zone_name
    provider = local.public_dns_zone_provider
  }
  dns_zone_name_private = google_dns_managed_zone.private-zone.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site                     = var.datadog_site
  datadog_trace_enabled            = true
  database_connection_name         = module.main-db.instance_connection_name
  redis_host                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].address
  redis_port                       = google_redis_cluster.redis-cluster-default.discovery_endpoints[0].port
  gke_cluster_name                 = module.container-cluster-default[0].cluster_name
  gke_cluster_namespace            = local.gke_workload_namespace_for_services_apps
  cloudsql_instance_name           = module.main-db.instance_name
  managed_ssl_certificate_name     = google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert_ex.name
  project_number                   = google_project.deployment-project.number
  cdp_streams_bigtable_events_table_ids = [google_bigtable_table.cdp-streams-bigtable-table-user-events.name, google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name]
  cdp_streams_bigtable_instance_id = google_bigtable_instance.cdp-streams-bigtable-instance.name
}

module "spiffy-react-components-publisher" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data
  ]
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name     = "spiffy-react-components"
  source           = "./services/spiffy-react-components-publish-job"
  environment      = var.environment
  project_id       = var.project_id
  docker_image     = module.git-repo-for-spiffy-react-components[0].docker_image
  docker_image_tag = var.environment == "prod" ? module.git-repo-for-spiffy-react-components[0].docker_image_prod_tag : module.git-repo-for-spiffy-react-components[0].docker_image_latest_tag
  region           = var.region_default
  vpc_name         = google_compute_network.vpc-deployment.name
  subnet_name      = google_compute_subnetwork.deployment-subnet-dmz.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site          = var.datadog_site
  datadog_trace_enabled = true
}

module "merchants-proxy" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data
  ]
  count = contains(["dev"], var.environment) ? 1 : 0 # Only in dev
  service_name       = "merchants-proxy"
  source             = "./services/merchants-proxy"
  environment        = var.environment
  project_id         = var.project_id
  docker_image       = module.git-repo-for-merchants-proxy[0].docker_image
  docker_image_tag   = var.environment == "prod" ? module.git-repo-for-merchants-proxy[0].docker_image_prod_tag : module.git-repo-for-merchants-proxy[0].docker_image_latest_tag
  region             = var.region_default
  vpc_name           = google_compute_network.vpc-deployment.name
  subnet_name        = google_compute_subnetwork.deployment-subnet-dmz.name
  domain_name_public = "merchants-proxy.${local.domain_name_suffix}"
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

module "envive-analytics-sdk-publisher" {

  depends_on = [
    google_project_service.all,
    data.google_container_cluster.gke-dws-cluster-default-data,
    data.google_container_cluster.container-cluster-default-data,
    data.google_container_cluster.container-cluster-secondary-region-data
  ]
  count = contains(["dev", "prod"], var.environment) ? 1 : 0 # Only in dev or prod
  service_name     = "envive-analytics-sdk"
  source           = "./services/envive-analytics-sdk-publish"
  environment      = var.environment
  project_id       = var.project_id
  docker_image     = module.git-repo-for-envive-analytics-sdk[0].docker_image
  docker_image_tag = var.environment == "prod" ? module.git-repo-for-envive-analytics-sdk[0].docker_image_prod_tag : module.git-repo-for-envive-analytics-sdk[0].docker_image_latest_tag
  region           = var.region_default
  vpc_name         = google_compute_network.vpc-deployment.name
  subnet_name      = google_compute_subnetwork.deployment-subnet-dmz.name
  datadog_api_key = {
    secret  = data.google_secret_manager_secret_version.datadog_api_key.secret
    version = data.google_secret_manager_secret_version.datadog_api_key.version
  }
  datadog_site          = var.datadog_site
  datadog_trace_enabled = true
}