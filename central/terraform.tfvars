org_id = 444735975015  # Spiffy.ai org in GCP
org_name              = "spiffy"
billing_account_name  = "GCP-Spiffy-Billing-Account"
project_name          = "spiffy-central"
project_id            = "spiffy-central"
project_id_for_quotas = "inner-tokenizer"

cidr_block               = "10.12.0.0/16"
dev_cidr_block           = "10.0.0.0/16"
dev_training_cidr_block  = "10.1.0.0/16"
prod_cidr_block          = "10.3.0.0/16"
prod_training_cidr_block = "10.5.0.0/16"
bi_prod_cidr_block       = "10.192.0.0/16"
bi_dev_cidr_block        = "10.193.0.0/16"
vpn_client_cidr_block    = "172.16.32.0/22"
region = "us-west1" # Oregon

infra_alerts_email_address   = "prasad@spiffy.ai"

# CircleCI WIF — fills in circleci_wif.tf (keyless GCP auth for CCI jobs)
circleci_org_id     = "814ebb3d-776b-45c3-8a5d-5341d67c005d"
circleci_project_id = "3371b09a-2b38-464b-9e08-b25bc65b6ba2"
datadog_endpoint             = "https://api.us5.datadoghq.com/"
datadog_logs_intake_endpoint = "https://gcp-intake.logs.us5.datadoghq.com/api/v2/logs"
