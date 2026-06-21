resource "google_logging_metric" "ids_threat_detection" {
  name   = "ids_threat_detection_metric"
  filter = "logName=\"projects/${var.project_id}/logs/ids.googleapis.com%2Fthreat\" AND resource.type=\"ids.googleapis.com/Endpoint\" AND jsonPayload.alert_severity=(\"HIGH\" OR \"CRITICAL\")"
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}