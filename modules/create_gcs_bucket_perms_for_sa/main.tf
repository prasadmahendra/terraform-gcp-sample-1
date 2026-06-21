# Give cloud-build access to storage bucket containing deployment configs
resource "google_project_iam_custom_role" "project_iam_custom_role" {
  role_id     = var.custom_role_id_to_create
  project     = var.project_id
  title       = "Spiffy - Custom role for gcs access"
  description = "Spiffy - Custom role for gcs access for SA ${var.service_account_email}"
  permissions = var.storage_bucket_permissions
}

resource "google_project_iam_member" "project_iam_member" {

  project = var.project_id
  role    = google_project_iam_custom_role.project_iam_custom_role.id
  member  = "serviceAccount:${var.service_account_email}"

  # Tighten up the permissions here to only give access to configs bucket!
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
  condition {
    title       = "Spiffy - Limited storage access"
    description = "Spiffy - Limited storage access for SA"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.storage_bucket_name}\")"
  }
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = var.storage_bucket_name
  role   = google_project_iam_custom_role.project_iam_custom_role.id
  member = "serviceAccount:${var.service_account_email}"
}