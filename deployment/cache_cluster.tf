resource "google_network_connectivity_service_connection_policy" "cache_cluster_network_connectivity_service_connection_policy" {
  name          = "memorystore-redis-connection-policy"
  location      = var.region_default
  service_class = "gcp-memorystore-redis"
  description   = "Memorystore (redis) service connection policy"
  network       = google_compute_network.vpc-deployment.id
  psc_config {
    subnetworks = concat(
      google_compute_subnetwork.deployment-subnet-app[*].id,
      google_compute_subnetwork.deployment-subnet-dmz[*].id
    )
  }
}

resource "google_redis_cluster" "redis-cluster-default" {
  name        = "redis-cluster-default"
  shard_count = var.environment == "prod" ? 12 : 12 # The specified value must be between 3 and 250.
  psc_configs {
    network = google_compute_network.vpc-deployment.id
  }
  region                  = var.region_default
  replica_count           = var.environment == "prod" ? 1 : 0
  # node_type               = var.environment == "prod" ? "REDIS_HIGHMEM_MEDIUM" : "REDIS_SHARED_CORE_NANO"
  transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"
  authorization_mode      = "AUTH_MODE_DISABLED"
  depends_on              = [
    google_network_connectivity_service_connection_policy.cache_cluster_network_connectivity_service_connection_policy
  ]
  zone_distribution_config {
    mode = "MULTI_ZONE"
  }
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
    ]
  }
}