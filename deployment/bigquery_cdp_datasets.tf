module "bigquery_datasets_cdp_streams" {
  source                = "../modules/create_bigquery_dataset"
  project_id            = var.project_id
  dataset_id            = "cdp_datastreams"
  friendly_name         = "CDP (segment, rudderstack, simon etc.) data-streams"
  description           = "CDP data-streams"
  environment           = var.environment
  region                = var.region_default
  is_case_insensitive   = true
  storage_billing_model = "LOGICAL"
}

# resource "google_storage_bucket_object" "default" {
#   # This creates a fake message to create partition locations on the table.
#   # Otherwise, the table deployment fails.
#   name    = "segment/org_id=c5f59d64-e651-478f-82ac-8364c01c86ba/dt=2000-01-01/hr=00/min=00/fake_message.json"
#   content = "{\"column1\": \"XXX\"}"
#   bucket  = google_storage_bucket.cdp-streams-data-gcs-bucket.name
# }
#
# module "bigquery_datatable_segment_cdp_streams" {
#   count                                  = 0
#   source                                 = "../modules/create_biglake_gcs_datatable"
#   dataset_id                             = module.bigquery_datasets_cdp_streams.dataset_id
#   table_id                               = "cdp_datastream_table_segment"
#   datasource_bucket_name                 = google_storage_bucket.cdp-streams-data-gcs-bucket.name
#   datasource_bucket_path_incl_partitions = "/segment/{org_id:STRING}/{dt:STRING}/{hr:INTEGER}/{min:INTEGER}"
#   datasource_uris                        = ["gs://${google_storage_bucket.cdp-streams-data-gcs-bucket.name}/segment/*"]
#   description                            = "BigLake table for segment CDP data"
#   environment                            = var.environment
#   project_id                             = var.project_id
#   region                                 = var.region_default
#   datasource_format                      = "NEWLINE_DELIMITED_JSON"
#   table_schema                           = jsonencode([{ "name" : "column1", "type" : "STRING", "mode" : "NULLABLE" }])
# }

module "bigquery_datatable_for_segment_cdp_streams" {
  count               = 1
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "segment"
  description         = "BigQuery table for segment CDP data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "event", "timestamp"]
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
        "name": "type",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "event",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "message_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "version",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "channel",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    },
    {
        "name": "payload",
        "type": "JSON",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_rudderstack_cdp_streams" {
  count               = 1
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "rudderstack"
  description         = "BigQuery table for rudderstack CDP data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "event", "timestamp"]
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
        "name": "type",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "event",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "message_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "version",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "channel",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    },
    {
        "name": "payload",
        "type": "JSON",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_simondata_cdp_streams" {
  count               = 1
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "simondata"
  description         = "BigQuery table for simondata CDP data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "event", "timestamp"]
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
        "name": "type",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "event",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "message_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "version",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "channel",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    },
    {
        "name": "payload",
        "type": "JSON",
        "mode": "REQUIRED"
    }
]
EOF
}

module "bigquery_datatable_for_shopify_cdp_streams" {
  count               = 1
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_datasets_cdp_streams.dataset_id
  table_id            = "shopify"
  description         = "BigQuery table for shopify CDP data"
  environment         = var.environment
  project_id          = var.project_id
  region              = var.region_default
  deletion_protection = true
  clustering          = ["organization_id", "event", "timestamp"]
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
        "name": "type",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "event",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "message_id",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "version",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "anonymous_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "channel",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "timestamp",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    },
    {
        "name": "payload",
        "type": "JSON",
        "mode": "REQUIRED"
    }
]
EOF
}

