terraform {
  # https://developer.hashicorp.com/terraform/language/settings/backends/gcs
  # The bucket must exist prior to configuring the backend.
  backend "gcs" {
    prefix         = "terraform/deployment/state"
  }
}