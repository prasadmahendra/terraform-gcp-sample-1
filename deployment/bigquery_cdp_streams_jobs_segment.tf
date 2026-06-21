module "bigquery_datatable_for_segment_cdp_streams_user_id_mappings" {
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "segment_anonymous_id_to_user_id_mapping"
  description         = "BigQuery table for segment anonymous id to user id mappings data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "anonymous_id", "user_id", "timestamp"]
  time_partitioning = {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = 63113852000 # 2 years
  }
  table_schema = <<EOF
[
    {
        "name": "organization_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "first_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "last_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "display_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "email",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "phone",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "company_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_1",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_2",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_city",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_state",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_country",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_zip",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_segment_cdp_streams_user_id_mappings_transfer_job" {

  source                 = "../modules/create_bigquery_transfer_job"
  job_name               = "segment-cdp-streams-user-id-mapping"
  project_id             = var.project_id
  region                 = var.region_default
  schedule               = "every day 00:00"
  description            = ""
  destination_dataset_id = module.bigquery_datatable_for_segment_cdp_streams_user_id_mappings.dataset_id
  destination_table_name = module.bigquery_datatable_for_segment_cdp_streams_user_id_mappings.table_id
  environment            = var.environment
  query                  = <<SQL
      SELECT
       organization_id,
       anonymous_id,
       user_id,
       JSON_EXTRACT_SCALAR(payload, "$.traits.first_name") as first_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.last_name") as last_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.display_name") as display_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.email") as email,
       JSON_EXTRACT_SCALAR(payload, "$.traits.phone") as phone,
       JSON_EXTRACT_SCALAR(payload, "$.traits.company.name") as company_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_1") as address_address_1,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_2") as address_address_2,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_city") as address_city,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_state") as address_state,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_country") as address_country,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_zip") as address_zip,
       timestamp
      FROM `cdp_datastreams.segment`
      WHERE TIMESTAMP_TRUNC(timestamp, DAY) > TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -1445 MINUTE)
          AND TIMESTAMP_TRUNC(timestamp, DAY) <= TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -5 MINUTE)
          AND type = 'identify'
          AND user_id is not null
SQL
}


module "bigquery_datatable_for_rudderstack_cdp_streams_user_id_mappings" {
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "rudderstack_anonymous_id_to_user_id_mapping"
  description         = "BigQuery table for rudderstack anonymous id to user id mappings data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "anonymous_id", "user_id", "timestamp"]
  time_partitioning = {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = 63113852000 # 2 years
  }
  table_schema = <<EOF
[
    {
        "name": "organization_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "first_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "last_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "display_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "email",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "phone",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "company_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_1",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_2",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_city",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_state",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_country",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_zip",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_rudderstack_cdp_streams_user_id_mappings_transfer_job" {

  source                 = "../modules/create_bigquery_transfer_job"
  job_name               = "rudderstack-cdp-streams-user-id-mapping"
  project_id             = var.project_id
  region                 = var.region_default
  schedule               = "every day 00:00"
  description            = ""
  destination_dataset_id = module.bigquery_datatable_for_rudderstack_cdp_streams_user_id_mappings.dataset_id
  destination_table_name = module.bigquery_datatable_for_rudderstack_cdp_streams_user_id_mappings.table_id
  environment            = var.environment
  query                  = <<SQL
      SELECT
       organization_id,
       anonymous_id,
       user_id,
       JSON_EXTRACT_SCALAR(payload, "$.traits.first_name") as first_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.last_name") as last_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.display_name") as display_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.email") as email,
       JSON_EXTRACT_SCALAR(payload, "$.traits.phone") as phone,
       JSON_EXTRACT_SCALAR(payload, "$.traits.company.name") as company_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_1") as address_address_1,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_2") as address_address_2,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_city") as address_city,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_state") as address_state,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_country") as address_country,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_zip") as address_zip,
       timestamp
      FROM `cdp_datastreams.rudderstack`
      WHERE TIMESTAMP_TRUNC(timestamp, DAY) > TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -1445 MINUTE)
          AND TIMESTAMP_TRUNC(timestamp, DAY) <= TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -5 MINUTE)
          AND type = 'identify'
          AND user_id is not null
SQL
}

module "bigquery_datatable_for_simondata_cdp_streams_user_id_mappings" {
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "simondata_anonymous_id_to_user_id_mapping"
  description         = "BigQuery table for simondata anonymous id to user id mappings data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "anonymous_id", "user_id", "timestamp"]
  time_partitioning = {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = 63113852000 # 2 years
  }
  table_schema = <<EOF
[
    {
        "name": "organization_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "first_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "last_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "display_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "email",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "phone",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "company_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_1",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_2",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_city",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_state",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_country",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_zip",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_simondata_cdp_streams_user_id_mappings_transfer_job" {

  source                 = "../modules/create_bigquery_transfer_job"
  job_name               = "simondata-cdp-streams-user-id-mapping"
  project_id             = var.project_id
  region                 = var.region_default
  schedule               = "every day 00:00"
  description            = ""
  destination_dataset_id = module.bigquery_datatable_for_simondata_cdp_streams_user_id_mappings.dataset_id
  destination_table_name = module.bigquery_datatable_for_simondata_cdp_streams_user_id_mappings.table_id
  environment            = var.environment
  query                  = <<SQL
      SELECT
       organization_id,
       anonymous_id,
       user_id,
       JSON_EXTRACT_SCALAR(payload, "$.traits.first_name") as first_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.last_name") as last_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.display_name") as display_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.email") as email,
       JSON_EXTRACT_SCALAR(payload, "$.traits.phone") as phone,
       JSON_EXTRACT_SCALAR(payload, "$.traits.company.name") as company_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_1") as address_address_1,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_2") as address_address_2,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_city") as address_city,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_state") as address_state,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_country") as address_country,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_zip") as address_zip,
       timestamp
      FROM `cdp_datastreams.simondata`
      WHERE TIMESTAMP_TRUNC(timestamp, DAY) > TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -1445 MINUTE)
          AND TIMESTAMP_TRUNC(timestamp, DAY) <= TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -5 MINUTE)
          AND type = 'identify'
          AND user_id is not null
SQL
}

module "bigquery_datatable_for_shopify_cdp_streams_user_id_mappings" {
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "shopify_anonymous_id_to_user_id_mapping"
  description         = "BigQuery table for shopify anonymous id to user id mappings data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "anonymous_id", "user_id", "timestamp"]
  time_partitioning = {
    type          = "DAY"
    field         = "timestamp"
    expiration_ms = 63113852000 # 2 years
  }
  table_schema = <<EOF
[
    {
        "name": "organization_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "first_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "last_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "display_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "email",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "phone",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "company_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_1",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_address_2",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_city",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_state",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_country",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "address_zip",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_shopify_cdp_streams_user_id_mappings_transfer_job" {

  source                 = "../modules/create_bigquery_transfer_job"
  job_name               = "shopify-cdp-streams-user-id-mapping"
  project_id             = var.project_id
  region                 = var.region_default
  schedule               = "every day 00:00"
  description            = ""
  destination_dataset_id = module.bigquery_datatable_for_shopify_cdp_streams_user_id_mappings.dataset_id
  destination_table_name = module.bigquery_datatable_for_shopify_cdp_streams_user_id_mappings.table_id
  environment            = var.environment
  query                  = <<SQL
      SELECT
       organization_id,
       anonymous_id,
       user_id,
       JSON_EXTRACT_SCALAR(payload, "$.traits.first_name") as first_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.last_name") as last_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.display_name") as display_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.email") as email,
       JSON_EXTRACT_SCALAR(payload, "$.traits.phone") as phone,
       JSON_EXTRACT_SCALAR(payload, "$.traits.company.name") as company_name,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_1") as address_address_1,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_address_2") as address_address_2,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_city") as address_city,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_state") as address_state,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_country") as address_country,
       JSON_EXTRACT_SCALAR(payload, "$.traits.address.address_zip") as address_zip,
       timestamp
      FROM `cdp_datastreams.shopify`
      WHERE TIMESTAMP_TRUNC(timestamp, DAY) > TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -1445 MINUTE)
          AND TIMESTAMP_TRUNC(timestamp, DAY) <= TIMESTAMP_ADD(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY), INTERVAL -5 MINUTE)
          AND type = 'identify'
          AND user_id is not null
SQL
}