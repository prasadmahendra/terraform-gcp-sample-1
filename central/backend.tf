terraform {
  # https://developer.hashicorp.com/terraform/language/settings/backends/gcs
  # The bucket must exist prior to configuring the backend.
  backend "gcs" {
    bucket         = "spiffy-tfstate-central"
    prefix         = "terraform/central/state"
  }
}