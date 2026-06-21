locals {
  cdc_datasource_main_db = {
    db_name     = "main"
    db_schema  = "public"
    server_name = "cdc-main-db"
    tables_to_include = [
      "organizations",
      "organizations_config",
      "iam_roles",
      "iam_user_roles",
      "iam_users"
    ]
  }
  table_schema = <<EOF
[
    {
        "name": "db_name",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "db_schema",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "db_table",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "operation",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "table_schema",
        "type": "JSON",
        "mode": "REQUIRED"
    },
    {
        "name": "payload",
        "type": "JSON",
        "mode": "REQUIRED"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datasets_cdc_streams" {
  source                = "../modules/create_bigquery_dataset"
  project_id            = var.project_id
  dataset_id            = "cdc_datastreams"
  friendly_name         = "CDC data-streams"
  description           = "CDC data-streams (debezium) data"
  environment           = var.environment
  region                = var.region_default
  is_case_insensitive   = true
  storage_billing_model = "PHYSICAL"
}

module "bigquery_datatable_for_cdc_streams_main_db" {
  count               = length(local.cdc_datasource_main_db.tables_to_include)
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdc_streams.dataset_id
  table_id            = "cdc_${local.cdc_datasource_main_db.db_name}_${local.cdc_datasource_main_db.db_schema}_${local.cdc_datasource_main_db.tables_to_include[count.index]}"
  description         = "BigQuery table for cdc data from ${local.cdc_datasource_main_db.tables_to_include[count.index]}"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering = ["timestamp"]
  time_partitioning = {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = null
  }
  table_schema = local.table_schema
}

