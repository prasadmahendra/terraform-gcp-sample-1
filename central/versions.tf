terraform {
  required_version = "~> 1.13.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.36.0"
    }
    datadog = {
      source = "DataDog/datadog"
      version = "3.60.0"
    }
  }
}

provider "google" {
  # Configuration options
  project               = var.project_id # Spiffy.ai dev, prod and so on ...
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id_for_quotas # requires roles/serviceusage.serviceUsageConsumer
}

# Configure the Datadog provider
provider "datadog" {
  api_key = data.google_secret_manager_secret_version.datadog_api_key.secret_data
  app_key = data.google_secret_manager_secret_version.datadog_app_key.secret_data
  api_url = var.datadog_endpoint
}
