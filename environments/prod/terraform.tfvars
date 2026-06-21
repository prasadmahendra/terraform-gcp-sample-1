environment           = "prod"
default_eng_team      = "infra"
org_id                = 444735975015 # Spiffy.ai org in GCP
org_name              = "spiffy"
billing_account_name  = "GCP-Spiffy-Billing-Account"
project_name          = "spiffy-prod"
project_id            = "spiffy-prod"
project_id_for_quotas = "inner-tokenizer"

subnet_count     = 3
region_default   = "us-central1" # Iowa
region_secondary = "us-west1"    # Iowa

cidr_block_default_region                        = "10.3.0.0/16" # default region
cidr_block_default_region_app_subnet_alt_range_1 = "192.168.0.0/17"
cidr_block_default_region_app_subnet_alt_range_2 = "192.168.128.0/17"

cidr_block_secondary_region                        = "10.4.0.0/16" # secondary region - us-west1
cidr_block_secondary_region_app_subnet_alt_range_1 = "192.169.0.0/17"
cidr_block_secondary_region_app_subnet_alt_range_2 = "192.169.128.0/17"

cidr_block_for_datastream_vpc = "10.2.0.0/29"

central_cidr_block = "10.12.0.0/16"

compute_zones_gpus_default_region   = ["us-central1-a", "us-central1-c"]
compute_zones_gpus_secondary_region = ["us-west1-a", "us-west1-b"]

artifact_registry_docker_region = "us" # us multi-regional

datadog_enable_apm               = false
github_org_name                  = "spiffy-ai"
github_app_installation_id       = "46860982"
infra_alerts_email_address       = "prasad@spiffy.ai"
enable_private_build_worker_pool = false
datadog_site                     = "us5.datadoghq.com"
datadog_endpoint                 = "https://api.us5.datadoghq.com/"
datadog_logs_intake_endpoint     = "https://gcp-intake.logs.us5.datadoghq.com/api/v2/logs"

root_domain = "spiffy.ai"

gke_default_region_clusters_enabled   = true
gke_secondary_region_clusters_enabled = true
gke_dws_default_cluster_enabled       = true
gke_dws_default_cluster_region        = "primary_region"
gke_dws_default_cluster_compute_zones = ["us-central1-a", "us-central1-c"]
gke_dws_secondary_cluster_enabled     = false
gke_dws_secondary_cluster_region        = "primary_region"
gke_dws_secondary_cluster_compute_zones = ["us-central1-b", "us-central1-f"]

# Elastic search
elastic_cloud_gcp_region = "gcp-us-central1"

# Union AI
union_ai_cloud_enabled = false

# Google Cloud Composer
composer_cluster_enabled = false

aws_region     = "us-west-2"
aws_account_id = "357130007513"

pen_tester_bastion_host_enabled = false
pen_tester_ssh_pub_key          = ""
pen_tester_src_ip_address       = "35.182.86.97/32"

temporal_host           = "us-east4.gcp.api.temporal.io:7233"
temporal_namespace      = "spiffy-prod.w79qu"
text_embed_endpoint_url = "https://text-embed-search-idx-default.spiffy.ai/embed"

# CircleCI WIF — fills in circleci_wif.tf (keyless GCP auth for CCI jobs)
circleci_org_id     = "814ebb3d-776b-45c3-8a5d-5341d67c005d"
circleci_project_id = "3371b09a-2b38-464b-9e08-b25bc65b6ba2"