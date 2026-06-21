terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
    datadog = {
      source = "datadog/datadog"
    }
  }
  required_version = ">= 0.13"
}
