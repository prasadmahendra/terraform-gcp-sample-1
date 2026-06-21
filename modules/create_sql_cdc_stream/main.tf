locals {
  gcs_destinations      = var.enable_datastream.enabled && var.enable_datastream.destination != null ? [for dest in var.enable_datastream.destination : dest if dest.type == "gcs"] : []
  bigquery_destinations = var.enable_datastream.enabled && var.enable_datastream.destination != null ? [for dest in var.enable_datastream.destination : dest if dest.type == "bigquery"] : []
}

resource "google_datastream_private_connection" "private_connection" {
  display_name          = "CDC datastream private connection"
  location              = var.region
  private_connection_id = "cdc-datastream-private-connection"

  vpc_peering_config {
    vpc = var.vpc_id
    subnet = var.cidr_block_for_datastream_vpc
  }
}

resource "google_datastream_connection_profile" "postgresql-source" {
  count                 = var.enable_datastream.enabled ? 1 : 0
  display_name          = "SQL - ${var.enable_datastream.database_name} source"
  location              = var.region
  connection_profile_id = "source-profile-${var.enable_datastream.database_name}"

  postgresql_profile {
    hostname = var.enable_datastream.database_hostname
    port     = var.enable_datastream.database_hostname_port
    username = var.enable_datastream.database_username
    password = var.enable_datastream.database_username_password
    database = var.enable_datastream.database_name
  }

  private_connectivity {
    private_connection = google_datastream_private_connection.private_connection.id
  }
}

resource "google_datastream_connection_profile" "gcs_destinations_connection_profile" {
  count = length(local.gcs_destinations)
  display_name          = "GCS dest - ${local.gcs_destinations[count.index].bucket_name}"
  location              = var.region
  connection_profile_id = "destination-profile-${local.gcs_destinations[count.index].bucket_name}"
  gcs_profile {
    bucket    = local.gcs_destinations[count.index].bucket_name
    root_path = local.gcs_destinations[count.index].bucket_root_path
  }
}

module "bigquery_cdc_destination_dataset" {
  count = length(local.bigquery_destinations)
  source                = "../create_bigquery_dataset"
  project_id            = var.project_id
  dataset_id            = "cdc_sqldb_${var.enable_datastream.database_name}"
  friendly_name         = "SQL CDC stream dest for ${var.enable_datastream.database_name} db"
  description           = "SQL CDC stream dest for ${var.enable_datastream.database_name} db"
  environment           = var.environment
  region                = var.region
  is_case_insensitive   = false
  storage_billing_model = "PHYSICAL"
}

resource "google_datastream_connection_profile" "bigquery_destination_connection_profile" {
  count = length(local.bigquery_destinations)
  display_name          = "BQ dest - ${module.bigquery_cdc_destination_dataset[0].dataset_id}"
  location              = var.region
  connection_profile_id = "destination-profile-${module.bigquery_cdc_destination_dataset[0].dataset_id}"
  bigquery_profile {}
}

resource "google_datastream_stream" "bigquery-destination-stream" {
  count = length(local.bigquery_destinations)
  stream_id    = "bq-cdc-sqldb-${var.enable_datastream.database_name}"
  location     = var.region
  display_name = "BQ CDC stream for ${var.enable_datastream.database_name}"
  source_config {
    source_connection_profile = google_datastream_connection_profile.postgresql-source[0].id
    postgresql_source_config {
      publication      = "data_stream_publication"
      replication_slot = "data_stream_replication_slot"
      include_objects {
        postgresql_schemas {
          schema = "public"
          postgresql_tables {
            table = "table"
            # postgresql_columns {
            #  column = "column"
            # }
          }
        }
      }
    }
  }
  destination_config {
    destination_connection_profile = google_datastream_connection_profile.bigquery_destination_connection_profile[0].id
    bigquery_destination_config {
      source_hierarchy_datasets {
        dataset_template {
          location = var.region
        }
      }
      append_only {}
    }
  }

  backfill_none {
  }
}
