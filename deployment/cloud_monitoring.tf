locals {
}

resource "google_monitoring_alert_policy" "cpu_utilization_alert" {
  display_name = "CPU Utilization Alert (Managed by Terraform)"
  project      = var.project_id

  conditions {
    display_name = "GCE: CPU utilization (Managed by Terraform)"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "60s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id
  ]

  combiner = "OR"
  enabled  = true
}

resource "google_monitoring_alert_policy" "cpu_utilization_alert_cloud_sql" {
  display_name = "CPU Utilization Alert for Cloud SQL Instances (Managed by Terraform)"
  project      = var.project_id

  conditions {
    display_name = "CPU Utilization Condition for Cloud SQL Instances (Managed by Terraform)"
    condition_threshold {
      # filter          = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.label.database_id=one_of(\"maindb-288a2197\", \"maindb-498d187e\")"
      filter          = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.type=\"cloudsql_database\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "60s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id,
    google_monitoring_notification_channel.email_notification_channel.id,
  ]
  combiner = "OR"
}

resource "google_monitoring_alert_policy" "disk_io_alert_for_cloud_sql" {
  count = 1
  display_name = "Disk I/O Alert for Cloud SQL Instances (Managed by Terraform)"
  combiner     = "OR"
  conditions {
    display_name = "Disk read I/O high threshold exceeded"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloudsql_database\"",
        "metric.type = \"cloudsql.googleapis.com/database/disk/read_ops_count\""
      ])
      duration   = "300s"  # 5 minutes
      comparison = "COMPARISON_GT"
      # Baseline observed ~500–1000 ops at rest; peaks during batch ops reach ~3500.
      # Cloud SQL SSD provisions ~30 IOPS/GB — revisit this threshold if disk autoscales
      # past ~200 GB (where provisioned limit would reach ~6000 ops).
      threshold_value = 4000

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  conditions {
    display_name = "Disk write I/O high threshold exceeded (Managed by Terraform)"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloudsql_database\"",
        "metric.type = \"cloudsql.googleapis.com/database/disk/write_ops_count\""
      ])
      duration   = "300s"  # 5 minutes
      comparison = "COMPARISON_GT"
      # Baseline observed ~2000–3000 ops at rest; peaks during batch ops reach ~4000.
      # Cloud SQL SSD provisions ~30 IOPS/GB — revisit this threshold if disk autoscales
      # past ~200 GB (where provisioned limit would reach ~6000 ops).
      threshold_value = 5000

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id,
    google_monitoring_notification_channel.email_notification_channel.id,
  ]

  documentation {
    content = <<-EOT
      Disk write I/O operations have exceeded the defined threshold.

      Possible causes:
      - Heavy write workload
      - Batch operations
      - Large data modifications
      - Excessive index updates

      Recommended actions:
      1. Review write-heavy operations
      2. Check for batch jobs timing
      3. Consider write optimization
      4. Evaluate index strategy
    EOT
    mime_type = "text/markdown"
  }
}

# sql memory utilization alert
resource "google_monitoring_alert_policy" "memory_utilization_alert_cloud_sql" {
  display_name = "Memory Utilization Alert for Cloud SQL Instances (Managed by Terraform)"
  project      = var.project_id

  conditions {
    display_name = "Memory Utilization Condition for Cloud SQL Instances (Managed by Terraform)"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/memory/utilization\" AND resource.type=\"cloudsql_database\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "60s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id,
    google_monitoring_notification_channel.email_notification_channel.id,
  ]
  combiner = "OR"
}

# SQL database disk utilization monitored (GCP)
# NOTE: Previously this used disk/bytes_used with COMPARISON_LT which fired
# when usage was LOW (the opposite of intended behavior). Fixed to use
# disk/utilization (0.0–1.0 ratio) with COMPARISON_GT at 80%.
resource "google_monitoring_alert_policy" "free_storage_space_alert_cloud_sql" {
  display_name = "Disk Utilization Alert for Cloud SQL Instances (Managed by Terraform)"
  project      = var.project_id

  conditions {
    display_name = "Disk Utilization Condition for Cloud SQL Instances (Managed by Terraform)"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" AND resource.type=\"cloudsql_database\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.981  # 98.1% — backup escalation above Datadog critical (0.9); Datadog handles 0.8 warning and 0.9 critical via OpsGenie
      duration        = "300s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_NONE"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id,
    google_monitoring_notification_channel.email_notification_channel.id,
  ]
  combiner = "OR"

  documentation {
    content   = "Cloud SQL disk utilization has exceeded 93%. This is a last-resort alert — Datadog should have already paged on-call at 80% (warning) and 90% (critical). Investigate disk usage immediately, clean up unnecessary data, and consider increasing disk size. Verify automatic storage increase is enabled."
    mime_type = "text/markdown"
  }
}

# IDS threat monitoring
resource "google_monitoring_alert_policy" "ids_threat_alert" {
  display_name = "IDS Threat Detection Alert"
  combiner     = "OR"

  conditions {
    display_name = "IDS Threat Condition"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"ids.googleapis.com/Endpoint\"",
        "metric.type = \"logging.googleapis.com/user/ids_threat_detection_metric\""
      ])

      # Add appropriate aggregations
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id
  ]

  documentation {
    content  = "Alert for IDS threat detections with high or critical severity."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "pubsub_message_age" {
  display_name = "Pub/Sub Message Age Alert"

  conditions {
    display_name = "Oldest Unacked Message Age Condition"
    condition_threshold {
      filter          = "resource.type = \"pubsub_subscription\" AND metric.type = \"pubsub.googleapis.com/subscription/oldest_unacked_message_age\""
      comparison      = "COMPARISON_GT"
      threshold_value = 900  # Set threshold value in seconds
      duration        = "60s"

      aggregations {
        # aggregation.perSeriesAligner had an invalid value of "ALIGN_RATE": The aligner cannot be applied to metrics with kind GAUGE and value type INT64.
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_NONE"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id
  ]
  combiner = "OR"
}

resource "google_monitoring_alert_policy" "bigtable_cpu_load" {
  display_name = "Bigtable: cluster CPU load"

  conditions {
    display_name = "Bigtable CPU Load Condition"
    condition_threshold {
      filter          = "resource.type = \"bigtable_cluster\" AND metric.type = \"bigtable.googleapis.com/cluster/cpu_load\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "60s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id
  ]
  combiner = "OR"
}

# Alert policy to monitor Bigtable cluster storage utilization.
resource "google_monitoring_alert_policy" "bigtable_cluster_storage_utilization" {
  display_name = "Bigtable Cluster Storage Utilization Alert"
  combiner     = "OR"

  documentation {
    content   = "Alert when Bigtable cluster storage utilization exceeds 80% over a 5-minute period."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "High Storage Utilization on Bigtable Cluster"
    condition_threshold {
      # Filter on the Bigtable storage utilization metric and resource type.
      filter     = "metric.type=\"bigtable.googleapis.com/cluster/storage_utilization\" AND resource.type=\"bigtable_cluster\""
      duration   = "300s"  # Evaluate over a 5-minute period.
      comparison = "COMPARISON_GT"
      threshold_value = 0.8  # Alert when storage utilization exceeds 80%.

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [
    data.google_monitoring_notification_channel.slack_notification_channel.id
  ]
}