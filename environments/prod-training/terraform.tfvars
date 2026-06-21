environment          = "prod-training"
org_id               = 444735975015  # Spiffy.ai org in GCP
org_name             = "spiffy"
billing_account_name = "GCP-Spiffy-Billing-Account"
project_name         = "spiffy-prod-training"
project_id           = "spiffy-prod-training"

cidr_block         = "10.5.0.0/16"
central_cidr_block = "10.12.0.0/16"
subnet_count       = 3
region             = "us-west1" # Oregon

datadog_enable_apm               = false
infra_alerts_email_address       = "prasad@spiffy.ai"
github_org_name                  = "spiffy-ai"
github_app_installation_id       = "46860982"
enable_private_build_worker_pool = false
datadog_site                     = "us5.datadoghq.com"
datadog_endpoint                 = "https://api.us5.datadoghq.com/"
datadog_logs_intake_endpoint     = "https://gcp-intake.logs.us5.datadoghq.com/api/v2/logs"

root_domain                  = "spiffy.ai"
gke_default_clusters_enabled = false