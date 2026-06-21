# Make dev remote state outputs available
data "terraform_remote_state" "dev" {
  backend = "gcs"
  config = {
    bucket  = "spiffy-tfstate-dev"
    prefix  = "terraform/deployment/state"
  }
}

# Make prod remote state outputs available
data "terraform_remote_state" "prod" {
  backend = "gcs"
  config = {
    bucket  = "spiffy-tfstate-prod"
    prefix  = "terraform/deployment/state"
  }
}

# Make central remote state outputs available
data "terraform_remote_state" "central" {
  backend = "gcs"
  config = {
    bucket  = "spiffy-tfstate-central"
    prefix  = "terraform/central/state"
  }
}