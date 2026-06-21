# https://cloud.google.com/sql/docs/postgres/replication/configure-logical-replication
# https://debezium.io/documentation/reference/operations/debezium-server.html
# https://medium.com/google-cloud/change-data-capture-with-debezium-server-on-gke-from-cloudsql-for-postgresql-to-pub-sub-d1c0b92baa98

terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

locals {
  service_container_port      = 8080
  target_service_port         = 8080
  number_of_replicas          = 1
  gcs_instance_capacity       = var.environment == "prod" ? "10Mi" : "10Mi"
  db_name                     = var.data_source.db_name
  server_name                 = var.data_source.server_name
  tables_to_include           = [
    for table in var.data_source.tables_to_include : "${var.data_source.db_schema}.${table}"
  ]
  tables_to_include_string = join(",", local.tables_to_include)
}

resource "google_service_account" "service_account" {
  account_id   = "${var.service_name}-gsa"
  display_name = "Managed by Terraform - SA for ${var.service_name}"
  project      = var.project_id
}

resource "google_project_iam_custom_role" "google_project_iam_custom_role_sql" {
  role_id     = "spiffy.cdcSvcSqlAccessRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - cloudsql access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "cloudsql.instances.connect",
    "cloudsql.instances.get",
  ]
}

resource "google_project_iam_member" "iam_member_for_custom_role_cloudsql_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.google_project_iam_custom_role_sql.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  condition {
    title       = "Allow cloudsql access"
    description = "Terraform Managed - Allow cloudsql access"
    expression  = <<EXPR
resource.name.startsWith("projects/${var.project_id}/instances/${var.cloudsql_instance_name}")
EXPR
  }
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_pubsub_access" {
  role_id     = "spiffy.cdcSvcPubSubRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - pubsub topics access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "pubsub.topics.attachSubscription",
      "pubsub.topics.publish",
    ],
  )
}

module "cdc-stream-topics" {
  count                  = length(local.tables_to_include)
  source                 = "../../../modules/create_pubsub_topic"
  topic_name             = "${local.server_name}.${local.tables_to_include[count.index]}"
  project_id             = var.project_id
  allowed_persistence_regions = null # [var.region]
  message_retention_duration = "604800s" # 7 days
  with_dead_letter_queue = true
}

resource "google_project_iam_custom_role" "iam_custom_role_for_service_pubsub_unscoped_access" {
  role_id     = "spiffy.cdcSvcPubSubUnscopedRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - pubsub subs access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = concat(
    [
      "pubsub.subscriptions.list",
      "pubsub.subscriptions.get",
      "pubsub.subscriptions.create",
      "pubsub.subscriptions.consume",
      "pubsub.snapshots.seek"
    ],
  )
}

# gcs role
resource "google_project_iam_custom_role" "iam_custom_role_for_service_gcs_access" {
  role_id     = "spiffy.cdcSvcGcsRole"
  project     = var.project_id
  title       = "Role for ${var.service_name} - gcs access"
  description = "Terraform Managed - Role for ${var.service_name} service"
  permissions = [
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
  ]
}

# MountVolume.SetUp failed for volume "cdc-main-db-gcs-pv" : rpc error: code = PermissionDenied desc = failed to
# get GCS bucket "spiffy-cdc-states-dev": googleapi: Error 403: cdc-main-db-gsa@spiffy-ai-dev.iam.gserviceaccount.com does not have storage.objects.list
# access to the Google Cloud Storage bucket. Permission 'storage.objects.list' denied on resource (or it may not exist)., forbidden
resource "google_project_iam_member" "iam_member_for_custom_role_gcs_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_gcs_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  condition {
    title       = "Allow gcs access"
    description = "Terraform Managed - Allow gcs access"
    expression  = <<EXPR
resource.name.startsWith("projects/_/buckets/${var.service_gcs_bucket_name}")
EXPR
  }
}

resource "google_project_iam_member" "iam_member_for_custom_role_pubsub_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_pubsub_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  # https://cloud.google.com/iam/docs/full-resource-names
  # https://cloud.google.com/iam/docs/conditions-resource-attributes#resource-name
  #   condition {
  #     title       = "Allow pubsub access"
  #     description = "Terraform Managed - Allow pubsub access"
  #     expression  = <<EXPR
  # resource.name.startsWith("${var.chat_sessions_topic_id}")
  # EXPR
  #   }
}

resource "google_project_iam_member" "iam_custom_role_for_service_pubsub_unscoped_access" {
  project = var.project_id
  role    = google_project_iam_custom_role.iam_custom_role_for_service_pubsub_unscoped_access.id
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

module "service-gcs-bucket-pv" {
  source                            = "../../../modules/create_gke_gcs_volume"
  bucket_name                       = var.service_gcs_bucket_name
  environment                       = var.environment
  persistent_volume_capacity        = local.gcs_instance_capacity
  persistent_volume_claim_name      = "${var.service_name}-gcs-pvc"
  persistent_volume_claim_namespace = var.cluster_namespace
  persistent_volume_name            = "${var.service_name}-gcs-pv"
  read_only                         = false
  mount_options = [
    "file-mode=0777",
    "dir-mode=0777",
  ]
}

data "google_secret_manager_secret_version" "cloudsql-maindb-datastream-user-password" {
  secret  = "cloudsql-maindb-datastream-user-password"
  project = var.project_id
}

# create a path under the bucket
resource "google_storage_bucket_object" "cdc-streams-data-gcs-bucket-object" {
  bucket  = var.service_gcs_bucket_name
  name = "${local.db_name}/"  # folder name should end with '/'
  content = " "                 # content is ignored but should be non-empty
}

module "debezium-service" {
  source               = "../../../modules/create_gke_http_service"
  kubernetes_namespace = var.cluster_namespace
  service_name         = var.service_name
  container_dns_label  = var.service_name
  container_port       = local.service_container_port
  docker_image         = "debezium/server"
  docker_image_tag     = "3.0.0.Final"
  environment          = var.environment
  subnet               = var.subnet
  region               = var.region
  service_port         = local.target_service_port
  number_of_replicas   = local.number_of_replicas
  run_as_non_root      = false
  google_service_account_for_the_service = {
    id    = google_service_account.service_account.id
    email = google_service_account.service_account.email
    account_id = google_service_account.service_account.account_id
  }
  cloudsql_databases = [
    {
      port                     = 5432
      instance_connection_name = var.database_connection_name
    }
  ]
  env = [
    {
      name  = "LOG_LEVEL"
      value = "DEBUG"
    },
    {
      name  = "CONNECT_LOG4J_ROOT_LOGLEVEL"
      value = "DEBUG"
    },
    {
      name  = "DEBEZIUM_LOG_LEVEL"
      value = "DEBUG"
    },
    {
      name  = "CONNECT_LOG4J_LOGGERS"
      value = "io.debezium=DEBUG,org.apache.kafka.connect=DEBUG"
    },
    {
      name  = "POSTGRES_USER"
      value = "datastreamuser"
    },
    {
      name  = "POSTGRES_HOSTNAME"
      value = "127.0.0.1" # connect to SQL proxy via private IP
    },
    {
      name      = "POSTGRES_PASSWORD"
      value     = data.google_secret_manager_secret_version.cloudsql-maindb-datastream-user-password.secret_data
      sensitive = true
    },
  ]
  config_maps = [
    {
      name       = "debezium-config"
      mount_path = "/debezium/config"
      read_only = true
      # debezium.sink.pubsub.ordering.key=${local.server_name}
      data = {
        "application.properties" = <<-EOF
debezium.sink.type=pubsub
debezium.sink.pubsub.project.id=${var.project_id}
debezium.sink.pubsub.ordering.enabled=false
debezium.sink.pubsub.topic.prefix=${var.service_name}
debezium.source.connector.class=io.debezium.connector.postgresql.PostgresConnector
debezium.source.topic.prefix=${var.service_name}
debezium.source.offset.storage.file.filename=/debezium/data/${local.db_name}/offsets.dat
debezium.source.offset.flush.interval.ms=0
debezium.source.database.hostname=127.0.0.1
debezium.source.database.port=5432
debezium.source.database.user=datastreamuser
debezium.source.database.password=${data.google_secret_manager_secret_version.cloudsql-maindb-datastream-user-password.secret_data}
debezium.source.database.dbname=${local.db_name}
debezium.source.database.server.name=${local.server_name}
debezium.source.table.include.list=${local.tables_to_include_string}
debezium.source.slot.name=data_stream_replication_slot
debezium.source.slot.drop.on.stop=false
debezium.source.plugin.name=pgoutput
debezium.heartbeat.interval.ms=10000
EOF
      }
    }
  ]
  persistent_volumes = [
    {
      name                         = "debezium-data-volume"
      mount_path                   = "/debezium/data"
      read_only                    = false
      persistent_volume_claim_name = module.service-gcs-bucket-pv.persistent_volume_claim_name
    }
  ]
  project_id                        = var.project_id
  project_number                    = var.project_number
  liveness_probe                    = null
  readiness_probe                   = null
  # liveness_probe = {
  #   grpc = null
  #   http_get = {
  #     path = "/health"
  #     port = local.service_container_port
  #   }
  #   initial_delay_seconds = 300
  #   period_seconds        = 60
  #   failure_threshold     = 2
  #   success_threshold     = 1
  #   timeout_seconds       = 10
  # }
  # readiness_probe = {
  #   grpc = null
  #   http_get = {
  #     path = "/health"
  #     port = local.service_container_port
  #   }
  #   initial_delay_seconds = 120
  #   period_seconds        = 60
  #   failure_threshold     = 2
  #   success_threshold     = 1
  #   timeout_seconds       = 10
  # }
  limits_cpus                       = var.cpu_alloc_max
  limits_memory                     = var.memory_alloc_max
  limits_nvidia_gpus                = null
  requests_cpus                     = var.cpu_alloc_min
  requests_memory                   = var.memory_alloc_min
  requests_nvidia_gpus              = null
  gpu_accelerator_type              = null
  is_public                         = false
  enable_service_directory_registry = false
  service_directory_namespace_id    = var.service_directory_namespace_id
  managed_ssl_certificate_name      = var.managed_ssl_certificate_name
  service_fqdn                      = var.service_fqdn
  private_dns_zone_name             = var.private_dns_zone_name
  public_dns_zone_name              = var.public_dns_zone_name
  set_shm_to_memory                 = false
  apm_enabled                       = false
}

module "logs-monitoring" {
  count        = 0
  source       = "../../../modules/create_dd_logs_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} logs monitor (Managed by Terraform)"
  service_name = var.service_name
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}

module "logs-anomalies-monitoring" {
  source       = "../../../modules/create_dd_logs_anomalies_monitor"
  environment  = var.environment
  monitor_name = "${var.service_name} log anomalies monitor (Managed by Terraform)"
  service_name = var.service_name
  priority     = 2
  team         = var.team
  chapter      = var.chapter
  additional_tags = []
}
