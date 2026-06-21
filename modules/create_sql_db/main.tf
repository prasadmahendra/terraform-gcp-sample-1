# why private IPs suck
# https://medium.com/google-cloud/cloud-sql-with-private-ip-only-the-good-the-bad-and-the-ugly-de4ac23ce98a

locals {
  edition = var.environment == "prod" ? "ENTERPRISE_PLUS" : "ENTERPRISE"
  tier    = var.environment == "prod" ? "db-perf-optimized-N-4" : "db-custom-${var.cpu_count}-${var.memory_size_gb * 1024}"
}

module "postgresql-db" {

  source               = "GoogleCloudPlatform/sql-db/google//modules/postgresql"
  version              = "~> 25.2"
  name                 = var.cluster_name
  random_instance_name = true
  database_version     = "POSTGRES_17"
  project_id           = var.project_id
  region               = var.region
  edition              = local.edition
  data_cache_enabled   = var.environment == "prod" ? true : false

  deletion_protection = true
  db_name             = var.default_db_name
  db_charset          = "UTF8"
  db_collation        = "en_US.UTF8"
  enable_default_db   = true
  enable_default_user = true
  user_name           = var.default_db_user_name
  user_password       = var.default_db_password
  root_password       = var.super_user_password

  # https://cloud.google.com/sql/docs/mysql/instance-settings
  # https://cloud.google.com/sql/docs/postgres/instance-settings#machine-type-2ndgen
  tier                            = local.tier
  availability_type               = var.availability_type
  maintenance_window_day          = 7
  maintenance_window_hour         = 12
  maintenance_window_update_track = "stable"
  database_flags = [
    { name = "autovacuum", value = "off" },
    { name = "max_connections", value = var.environment == "prod" ? "1024" : "512" },
    { name = "cloudsql.logical_decoding", value = "on" },
  ]

  # module_depends_on    = [google_service_networking_connection.service_networking_connection_to_vpc]
  # See https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#private-ip-instance

  additional_databases = var.additional_databases
  additional_users     = var.additional_users
  insights_config = {
    query_insights_enabled  = null
    query_plans_per_minute  = null
    query_string_length     = null
    record_application_tags = null
    record_client_address   = null
  }
  ip_configuration = {
    allocated_ip_range                            = null,
    authorized_networks                           = var.authorized_networks,
    ipv4_enabled                                  = var.ipv4_enabled,
    enable_private_path_for_google_cloud_services = true
    private_network                               = var.vpc_id
    require_ssl                                   = var.require_ssl_for_connections
  }

  disk_type             = "PD_SSD"
  disk_size             = 32
  disk_autoresize       = true
  disk_autoresize_limit = var.disk_autoresize_limit

  backup_configuration = {
    enabled                        = true
    start_time                     = "20:55"
    location                       = null
    point_in_time_recovery_enabled = false
    transaction_log_retention_days = null
    retained_backups               = var.retained_backups
    retention_unit                 = var.retention_unit
  }

  // Read replica configurations
  read_replica_name_suffix = "-read-replica"
  read_replicas            = var.enable_read_replicas ? [
    {
      name              = var.cluster_name
      availability_type = var.availability_type
      tier              = "db-custom-${var.cpu_count}-${var.memory_size_gb * 1024}"
      ip_configuration = {
        ipv4_enabled                                  = true
        ssl_mode                                      = "ENCRYPTED_ONLY"
        allocated_ip_range                            = null
        enable_private_path_for_google_cloud_services = true
        private_network                               = var.vpc_id
        require_ssl                                   = var.require_ssl_for_connections
        authorized_networks = [
          {
            name  = var.allowed_external_ip_range_name
            value = var.allowed_external_ip_range
          },
        ]
      }
      database_flags = [{ name = "autovacuum", value = "off" }]
      disk_autoresize       = null
      disk_autoresize_limit = null
      disk_size             = null
      disk_type             = "PD_SSD"
      user_labels = { bar = "baz" }
      encryption_key_name   = null
    },
  ] : []
}
