resource "google_firestore_database" "spiffy-annotations-store" {
  project                           = google_project.deployment-project.project_id
  name                              = "spiffy-annotations-store"
  location_id                       = var.region_default
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "OPTIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = var.environment == "prod" ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"
  deletion_policy                   = "DELETE"
}

resource "google_firestore_database" "spiffy-chat-sessions-store" {
  project                           = google_project.deployment-project.project_id
  name                              = "spiffy-chat-sessions-store"
  location_id                       = var.region_default
  type                              = "FIRESTORE_NATIVE"
  concurrency_mode                  = "PESSIMISTIC"
  app_engine_integration_mode       = "DISABLED"
  point_in_time_recovery_enablement = var.environment == "prod" ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state           = "DELETE_PROTECTION_ENABLED"
  deletion_policy                   = "DELETE"
}

resource "google_firestore_backup_schedule" "spiffy-chat-sessions-store-daily-backup" {
  project   = var.project_id
  database  = google_firestore_database.spiffy-chat-sessions-store.name
  retention = var.environment == "prod" ? "604800s" : "172800s" # 2 days in DEV, 7 days in PROD
  daily_recurrence {}
}
