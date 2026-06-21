resource "google_pubsub_topic" "gke-cluster-notifications" {
  name    = "gke-cluster-notifications"
  project = var.project_id
  message_storage_policy {
    # annoyingly the order of the regions matters for terraform to not want to recreate the resource
    allowed_persistence_regions = sort([
      var.region_default,
      var.region_secondary,
    ])
  }
  message_retention_duration = "604800s" # 7 days
}