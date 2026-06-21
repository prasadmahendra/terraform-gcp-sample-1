terraform {
  required_version = "~> 1.13.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.44.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95.0"
    }
    datadog = {
      source = "DataDog/datadog"
      version = "~> 3.60.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.1"
    }
    ec = {
      source  = "elastic/ec"
      version = "~> 0.12.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
  }
}

provider "google" {
  # Configuration options
  project               = var.project_id # Spiffy.ai dev, prod and so on ...
  region                = var.region_default
  user_project_override = true
  billing_project       = var.project_id_for_quotas # requires roles/serviceusage.serviceUsageConsumer
}

# Configure the Datadog provider
provider "datadog" {
  # copy the data out of secrets manager and place it in secrets.tfvars
  # data.google_secret_manager_secret_version.datadog_api_key.secret_data
  api_key = var.datadog_api_key
  # copy the data out of secrets manager and place it in secrets.tfvars
  # data.google_secret_manager_secret_version.datadog_app_key.secret_data
  app_key = var.datadog_app_key
  api_url = var.datadog_endpoint
}

provider "ec" {
  # copy the data out of secrets manager and place it in secrets.tfvars
  # data.google_secret_manager_secret_version.elasticsearch_cloud_api_key.secret_data
  apikey = var.elasticsearch_cloud_api_key
}

provider "aws" {
  profile                     = "spiffy-prod"
  region                      = var.aws_region
  # Make it faster by skipping something
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}