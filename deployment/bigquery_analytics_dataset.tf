# Custom analytics events table — transformed from Amplitude's EVENTS_* export
# (prod EVENTS_616215, dev EVENTS_616216 — the ETL worker resolves the table per env).
#
# One typed top-level column per analytics dimension (vs. dimensions buried in
# JSON), so cross-org queries can cluster-prune on org_short_name instead of
# scanning every org's rows. See the spec at
# agent-os/specs/2026-03-13-0100-custom-bq-analytics-table in the envive repo.
#
# The ETL that fills this table is a Temporal worker (see the
# analytics-events-etl-worker service), not a BigQuery scheduled query.
#
# This is the "terraform table schema" layer of the three hand-coordinated layers
# (terraform schema, ETL dimension mapping in pymono
# spiffy/service/analytics/events_etl, consumer registry). The schema below is
# hand-edited to mirror the ETL dimension mapping;
# adding a column here + in the ETL mapping populates it on the next ETL run.

locals {
  # The analytics dataset MUST be co-located with the Amplitude export it MERGEs from
  # (a BigQuery MERGE can't span locations) — and that location is NOT var.region_default
  # (the GKE/compute region). The prod Amplitude export is the `US` multi-region; dev's
  # is `us-west1`. BigQuery then infers the MERGE job's location from these co-located
  # datasets, so no location needs to be set in the ETL code.
  analytics_dataset_location = var.environment == "prod" ? "US" : "us-west1"

  # Storage truth for analytics.events. event_date / pseudo_session are NOT stored:
  # they are derived at query time from event_time + the request timezone, so a
  # fixed-UTC copy would break timezone-aware grouping. The table partitions on
  # event_time directly, so no stored date column is needed for pruning.
  analytics_events_table_schema = <<EOF
[
    {
        "name": "event_time",
        "type": "TIMESTAMP",
        "mode": "REQUIRED"
    },
    {
        "name": "event_type",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "uuid",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "user_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "org_short_name",
        "type": "STRING",
        "mode": "REQUIRED"
    },
    {
        "name": "traffic_source",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "app_source",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "event_source",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "utm_source",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "country",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "device_type",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "device_family",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "device_category",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "platform",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "os_name",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "city",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "region",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_sales_agent_enabled",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_envive_enabled",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_search_enabled",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_event_source",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_app_source",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_page_variant",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_trigger_location",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_message_trigger_location",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_user_query",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_user_typed",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_message_content",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_search_query_text",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_query_text",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_click_position",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_title",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_filter_type",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v2_filter_value",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_page_type",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_page_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_page_variant_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_widget",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_widget_interaction",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_widget_interaction_product_id",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_widget_interaction_class",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_chat_request_type",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_chat_user_typed",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_chat_request_text",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_chat_response_time_ms",
        "type": "FLOAT64",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_chat_product_cards_returned",
        "type": "FLOAT64",
        "mode": "NULLABLE"
    },
    {
        "name": "v3_chat_product_ids_returned",
        "type": "STRING",
        "mode": "REPEATED"
    },
    {
        "name": "total_price",
        "type": "FLOAT64",
        "mode": "NULLABLE"
    },
    {
        "name": "currency_code",
        "type": "STRING",
        "mode": "NULLABLE"
    },
    {
        "name": "event_properties",
        "type": "JSON",
        "mode": "NULLABLE"
    },
    {
        "name": "user_properties",
        "type": "JSON",
        "mode": "NULLABLE"
    }
]
EOF
}

module "bigquery_dataset_analytics" {
  source                = "../modules/create_bigquery_dataset"
  project_id            = var.project_id
  dataset_id            = "analytics"
  friendly_name         = "Analytics (transformed event data)"
  description           = "Transformed analytics events derived from the Amplitude export (EVENTS_616215 prod / EVENTS_616216 dev)"
  environment           = var.environment
  region                = local.analytics_dataset_location
  is_case_insensitive   = false
  storage_billing_model = "LOGICAL"
}

module "bigquery_datatable_analytics_events" {
  source              = "../modules/create_bigquery_datatable"
  dataset_id          = module.bigquery_dataset_analytics.dataset_id
  table_id            = "events"
  description         = "Transformed Amplitude events — one typed column per dimension; clustered for cross-org cluster pruning"
  environment         = var.environment
  project_id          = var.project_id
  region              = local.analytics_dataset_location # unused by the module — a table inherits its dataset's location
  deletion_protection = true
  # Ordered by filter frequency + selectivity. traffic_source is deliberately
  # excluded — its value distribution is ~99% skewed in any one environment, so
  # pruning on it would only skip a small slice; the slot is better spent on
  # event_type / user_id. It stays a regular WHERE-clause column.
  clustering = ["org_short_name", "event_type", "user_id"]
  time_partitioning = {
    type          = "DAY"
    field         = "event_time"
    expiration_ms = null
  }
  table_schema = local.analytics_events_table_schema
}
