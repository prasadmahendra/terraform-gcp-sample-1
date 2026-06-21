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
      threshold_value = 300  # Set threshold value in seconds
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