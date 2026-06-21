locals {
  enable_skypilot = var.environment == "dev" ? false : false
}

resource "google_service_account" "skypilot_service_account" {
  count       = local.enable_skypilot == true ? 1 : 0
  project     = var.project_id
  account_id  = "skypilot-v1"
  description = "Managed By Terraform - SkyPilot service account"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_compute_admin" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/compute.admin"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_service_account_user" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/iam.serviceAccountUser"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_storage_admin" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/storage.admin"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_service_account_admin" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/iam.serviceAccountAdmin"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_roles_browser" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/browser"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_service_usage_consumer" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/serviceusage.serviceUsageConsumer"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_service_usage_admin" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/serviceusage.serviceUsageAdmin"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

resource "google_project_iam_member" "skypilot_service_account_iam_member_security_admin" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "roles/iam.securityAdmin"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}

# resource "google_project_iam_member" "skypilot_service_account_iam_member_pubsub_admin" {
#   count   = local.enable_skypilot == true ? 1 : 0
#   role    = "roles/pubsub.admin"
#   project = var.project_id
#   member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
# }

resource "google_project_iam_member" "skypilot_service_account_iam_member_services_enable" {
  count   = local.enable_skypilot == true ? 1 : 0
  role    = "serviceusage.services.enable"
  project = var.project_id
  member  = "serviceAccount:${google_service_account.skypilot_service_account[0].email}"
}
