# https://cloud.google.com/deploy/docs/deploying-application
# https://registry.terraform.io/modules/GoogleCloudPlatform/cloud-deploy/google/latest
# https://medium.com/@nikhil.nagarajappa/deploy-using-gcp-cloud-deploy-d9623cf3e750

resource "google_clouddeploy_delivery_pipeline" "clouddeploy_delivery_pipeline" {

  #provider    = google-beta
  name        = var.pipeline_name
  description = var.pipeline_description
  location    = var.region
  project     = var.project_id
  serial_pipeline {
    dynamic "stages" {
      for_each = var.stages
      content {
        target_id = stages.value.target_id
        profiles  = stages.value.profiles
      }
    }
  }
}