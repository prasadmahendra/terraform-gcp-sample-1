# create a regions to region codes map for use in other modules
locals {
  region_codes = {
    "us-west1"    = "usw1"
    "us-central1" = "usc1"
    "us-east1"    = "use1"
    "europe-west1" = "euw1"
    "asia-east1"   = "ase1"
  }
}