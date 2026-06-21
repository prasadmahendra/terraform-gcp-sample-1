locals {
  instance_name = "cdp-streams"
  display_name  = "CDP streams (n) days buffer"
  max_nodes     = var.environment == "prod" ? 1 : 1
  compute_zones = var.environment == "prod" ? data.google_compute_zones.available_zones.names : [data.google_compute_zones.available_zones.names[0]]
}

resource "google_bigtable_instance" "cdp-streams-bigtable-instance" {

  name                = local.instance_name
  display_name        = local.display_name
  deletion_protection = false
  project             = var.project_id

  dynamic "cluster" {
    for_each = local.compute_zones
    content {
      cluster_id = "${local.instance_name}-${cluster.value}"
      zone       = cluster.value
      autoscaling_config {
        min_nodes  = 1
        max_nodes  = local.max_nodes
        cpu_target = 75
      }
      storage_type = "SSD"
    }
  }

  labels = {
    env = var.environment
  }
}

resource "google_bigtable_table" "cdp-streams-bigtable-table-user-events" {
  name          = "user-activity"
  instance_name = google_bigtable_instance.cdp-streams-bigtable-instance.name

  column_family {
    family = "events"
  }
}

resource "google_bigtable_gc_policy" "policy" {
  instance_name   = google_bigtable_instance.cdp-streams-bigtable-instance.id
  table           = google_bigtable_table.cdp-streams-bigtable-table-user-events.name
  column_family   = "events"
  # deletion_policy = "ABANDON"
  # https://cloud.google.com/bigtable/docs/configuring-garbage-collection
  # Define a GC rule to drop cells older than 30 days or not the
  # most recent version
  gc_rules=<<EOF
    {
    "mode": "union",
    "rules": [
      {
        "max_age": "2592000s"
      },
      {
        "max_version": 2
      }
    ]
  }
  EOF
}

resource "google_bigtable_table" "spiffy-user-identity" {
  name          = "spiffy-user-identity"
  instance_name = google_bigtable_instance.cdp-streams-bigtable-instance.name

  column_family {
    family = "identity"
  }
}

resource "google_bigtable_gc_policy" "spiffy-user-identity-gc-policy" {
  instance_name   = google_bigtable_instance.cdp-streams-bigtable-instance.id
  table           = google_bigtable_table.spiffy-user-identity.name
  column_family   = "identity"
  # deletion_policy = "ABANDON"
  # https://cloud.google.com/bigtable/docs/configuring-garbage-collection
  # Define a GC rule to drop cells older than 30 days or not the
  # most recent version
  ignore_warnings = true
  gc_rules=<<EOF
    {
    "mode": "union",
    "rules": [
      {
        "max_age": "100d"
      },
      {
        "max_version": 100
      }
    ]
  }
  EOF
}

resource "google_bigtable_table" "spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping" {
  name          = "spiffy-user-identity-cdp-uid-to-spiffy-mapping"
  instance_name = google_bigtable_instance.cdp-streams-bigtable-instance.name

  column_family {
    family = "spiffy-user-id"
  }
}

resource "google_bigtable_gc_policy" "spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping-gc-policy" {
  instance_name   = google_bigtable_instance.cdp-streams-bigtable-instance.id
  table           = google_bigtable_table.spiffy-user-identity-cdp-user-id-to-spiffy-id-mapping.name
  column_family   = "spiffy-user-id"
  # deletion_policy = "ABANDON"
  # https://cloud.google.com/bigtable/docs/configuring-garbage-collection
  # Define a GC rule to drop cells older than 30 days or not the
  # most recent version
  ignore_warnings = true
  gc_rules=<<EOF
    {
    "mode": "union",
    "rules": [
      {
        "max_age": "100d"
      },
      {
        "max_version": 100
      }
    ]
  }
  EOF
}

resource "google_bigtable_table" "spiffy-user-identity-client-ip-to-spiffy-user-id-mapping" {
  name          = "spiffy-user-identity-ipaddr-to-spiffy-uid-mapping"
  instance_name = google_bigtable_instance.cdp-streams-bigtable-instance.name

  column_family {
    family = "spiffy-user-id"
  }
}

resource "google_bigtable_gc_policy" "spiffy-user-identity-client-ip-to-spiffy-uid-mapping-gc-policy" {
  instance_name   = google_bigtable_instance.cdp-streams-bigtable-instance.id
  table           = google_bigtable_table.spiffy-user-identity-client-ip-to-spiffy-user-id-mapping.name
  column_family   = "spiffy-user-id"
  # deletion_policy = "ABANDON"
  # https://cloud.google.com/bigtable/docs/configuring-garbage-collection
  # Define a GC rule to drop cells older than 30 days or not the
  # most recent version
  ignore_warnings = true
  gc_rules=<<EOF
    {
    "mode": "union",
    "rules": [
      {
        "max_age": "100d"
      },
      {
        "max_version": 100
      }
    ]
  }
  EOF
}