resource "random_string" "suffix" {
  length  = 6
  special = false
}

resource "google_project_iam_custom_role" "sa_subs_create_role" {
  role_id     = "spiffy.pubsubSpecPermsRole_${random_string.suffix.result}"
  project     = var.project_id
  title       = "Role for ${var.service_account_service_name} - pubsub subs access"
  description = "Terraform Managed - Role for ${var.service_account_service_name} service"
  permissions = concat(
    [
      "pubsub.subscriptions.create"
    ],
  )
}

# roles/pubsub.publisher
resource "google_project_iam_member" "sa_publisher_role" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.service_account_email}"
}

# roles/pubsub.subscriber
resource "google_project_iam_member" "sa_subscriber_role" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${var.service_account_email}"
}

# roles/pubsub.viewer
resource "google_project_iam_member" "sa_viewer_role" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "sa_create_subs_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.sa_subs_create_role.id
  member  = "serviceAccount:${var.service_account_email}"
}
