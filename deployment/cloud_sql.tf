locals {
  cloudsql_set_authorized_networks = false
}

resource "random_password" "coredb-cloudsql-root-password-generated" {
  length           = 16
  special          = true
  override_special = "!#$%&"
}

resource "google_secret_manager_secret" "maindb-cloudsql-root-password" {
  secret_id = "cloudsql-maindb-root-password"
  labels = {
    env = var.environment
  }
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "maindb-cloudsql-root-password-version" {
  secret      = google_secret_manager_secret.maindb-cloudsql-root-password.id
  secret_data = random_password.coredb-cloudsql-root-password-generated.result
}

resource "random_password" "coredb-cloudsql-maindb-password-generated" {
  length           = 16
  special          = true
  override_special = "!#$%&"
}

resource "google_secret_manager_secret" "maindb-cloudsql-maindb-password" {
  secret_id = "cloudsql-maindb-maindb-password"
  labels = {
    env = var.environment
  }
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "maindb-cloudsql-maindb-password-version" {
  secret      = google_secret_manager_secret.maindb-cloudsql-maindb-password.id
  secret_data = random_password.coredb-cloudsql-maindb-password-generated.result
}

module "main-db" {

  depends_on = [google_service_networking_connection.service_networking_connection_to_vpc]

  source                         = "../modules/create_sql_db"
  allowed_external_ip_range      = ""
  allowed_external_ip_range_name = ""
  cluster_name                   = "maindb"
  environment                    = var.environment
  project_id                     = google_project.deployment-project.project_id
  region = var.region_default
  # https://medium.com/google-cloud/cloud-sql-with-private-ip-only-the-good-the-bad-and-the-ugly-de4ac23ce98a
  vpc_id                         = google_compute_network.vpc-deployment.self_link
  ipv4_enabled                   = true
  availability_type = "REGIONAL"
  # instance settings https://cloud.google.com/sql/docs/mysql/instance-settings
  cpu_count                      = var.environment == "prod" ? 4 : 4
  enable_read_replicas           = false
  memory_size_gb                 = var.environment == "prod" ? 15 : 15
  disk_autoresize_limit          = var.environment == "prod" ? 12288 : 2048
  require_ssl_for_connections    = true
  ssl_mode_for_connections       = "ENCRYPTED_ONLY"
  retained_backups               = var.environment == "prod" ? 180 : 30
  retention_unit                 = "COUNT"
  default_db_name                = "main"
  default_db_user_name           = "maindbuser"
  default_db_password            = google_secret_manager_secret_version.maindb-cloudsql-maindb-password-version.secret_data
  super_user_password            = google_secret_manager_secret_version.maindb-cloudsql-root-password-version.secret_data
  authorized_networks            = local.cloudsql_set_authorized_networks ? [
    # '10.0.0.0/8', which is already automatically included in networks authorized by Cloud SQL
    # {
    #  name = "allow-app-vpc-subnet"
    #  value = "10.0.0.0/8"
    #},
    # "192.168.0.0/16", which is already automatically included in networks authorized by Cloud SQL
    # {
    #   name = "allow-app-vpc-subnet-alt-ranges"
    #   value = "192.168.0.0/16"
    # },
    {
      name = "allow-app-vpc-subnet-alt-ranges"
      value = "192.169.0.0/16"
    },

    # for datastream
    # https://cloud.google.com/datastream/docs/ip-allowlists-and-regions
    # us-west1 (oregon):
    # 35.247.10.221
    # 35.233.208.195
    # 34.82.253.59
    # 35.247.95.52
    # 34.82.254.46
    # us-central1 (iowa):
    # 34.72.28.29
    # 34.67.234.134
    # 34.67.6.157
    # 34.72.239.218
    # 34.71.242.81
    {
      name = "datastream-us-west1-1"
      value = "35.247.10.221/32"
    },
    {
      name  = "datastream-us-west1-2"
      value = "35.233.208.195/32"
    },
    {
      name  = "datastream-us-west1-3"
      value = "34.82.253.59/32"
    },
    {
      name  = "datastream-us-west1-4"
      value = "35.247.95.52/32"
    },
    {
      name  = "datastream-us-west1-5"
      value = "34.82.254.46/32"
    }
  ] : []
}

data "google_secret_manager_secret_version" "cloudsql-maindb-datastream-user-password" {
  secret  = "cloudsql-maindb-maindb-password"
  project = var.project_id
}

module "main-db-streams" {
  count                         = 0 # var.environment == "dev" ? 1 : 0
  depends_on = [module.main-db]
  source                        = "../modules/create_sql_cdc_stream"
  environment                   = var.environment
  project_id                    = google_project.deployment-project.project_id
  region                        = var.region_default
  vpc_id                        = google_compute_network.vpc-deployment.id
  cidr_block_for_datastream_vpc = var.cidr_block_for_datastream_vpc
  enable_datastream = {
    enabled                    = true
    database_name              = "main"
    database_hostname          = module.main-db.primary.public_ip_address
    database_hostname_port     = 5432
    database_username          = "datastreamuser"
    database_username_password = data.google_secret_manager_secret_version.cloudsql-maindb-datastream-user-password.secret_data
    enable_datastream          = true
    destination = [
      {
        type             = "bigquery"
        display_name     = "main-db cdc stream"
        bucket_name      = null
        bucket_root_path = null
        id               = null
      }
    ]
  }
}