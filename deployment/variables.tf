variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "default_eng_team" {
  description = "Name of team (e.g, infra, data, backend, frontend, etc)"
  type        = string
}

variable "region_default" {
  description = "default gcp region"
  type        = string
}

variable "region_secondary" {
  description = "secondary gcp region"
  type        = string
  default     = null
}

variable "artifact_registry_docker_region" {
  description = "gcp region for artifact registry docker"
  type        = string
}

variable "compute_zones_gpus_default_region" {
  description = "gcp compute zones with gpus for default region"
  type        = list(string)
}

variable "compute_zones_gpus_secondary_region" {
  description = "gcp compute zones with gpus for secondary region"
  type        = list(string)
}

variable "org_id" {
  description = "gcp organization id"
  type        = string
}

variable "org_name" {
  description = "organization name" # ex: spiffy
  type        = string
}

variable "project_name" {
  description = "gc project name"
  type        = string
}

variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "project_id_for_quotas" {
  description = "gcp project id for quotas"
  type        = string
}

variable "billing_account_name" {
  description = "gcp billing account name (unused - kept for backwards compat)"
  type        = string
  default     = ""
}

variable "billing_account_id" {
  description = "GCP billing account ID (e.g. 015900-535DF2-C09343)"
  type        = string
  default     = "015900-535DF2-C09343"
}

variable "cidr_block_default_region" {
  description = "CIDR block for VPC (home base for env)"
  type        = string
}

variable "cidr_block_default_region_app_subnet_alt_range_1" {
  description = "CIDR alt 1 app subnet block for VPC (default region)"
  type        = string
}

variable "cidr_block_default_region_app_subnet_alt_range_2" {
  description = "CIDR alt 1 app subnet block for VPC (default region)"
  type        = string
}

variable "cidr_block_secondary_region" {
  description = "CIDR alt 1 region region block for VPC"
  type        = string
}

variable "cidr_block_secondary_region_app_subnet_alt_range_1" {
  description = "CIDR alt 1 app subnet block for VPC (secondary region)"
  type        = string
}

variable "cidr_block_secondary_region_app_subnet_alt_range_2" {
  description = "CIDR alt 1 app subnet block for VPC (secondary region)"
  type        = string
}

variable "cidr_block_for_datastream_vpc" {
  description = "CIDR block for datastream vpc"
  type        = string
}

variable "central_cidr_block" {
  description = "CIDR blocks for VPN"
  type        = string
}

variable "subnet_count" {
  description = "Number of subnets in each network zone (e.g, 2 subnets in DMZ, 2 in APP, 2 in DATA)"
  type        = number
}

variable "datadog_enable_apm" {
  description = "Indicates if datadog apm agent should be used"
  type        = bool
}

variable "datadog_site" {
  description = "Datadog Site (eg: us5.datadoghq.com)"
  type        = string
}

variable "datadog_endpoint" {
  description = "datadog endpoint"
  type        = string
}

variable "datadog_logs_intake_endpoint" {
  description = "datadog logs intake endpoint"
  type        = string
}

variable "infra_alerts_email_address" {
  description = "email address to send infrastructure alerts to"
  type        = string
}

variable "github_org_name" {
  description = "Github organization name"
  type        = string
}

variable "github_app_installation_id" {
  description = "github app installation id"
  type        = string
}

variable "enable_private_build_worker_pool" {
  description = "Indicates if private build worker pool should be used (applicable in dev only)"
  type        = bool
}

variable "root_domain" {
  description = "root domain of the fqdn to be used (eg: spiffy.ai)"
  type        = string
}

variable "gke_default_region_clusters_enabled" {
  description = "Indicates if default gke clusters should be created"
  type        = bool
}

variable "gke_secondary_region_clusters_enabled" {
  description = "Indicates if secondary region gke clusters should be created"
  type        = bool
}

variable "gke_dws_default_cluster_enabled" {
  description = "Indicates if default GKE DWS cluster should be created"
  type        = bool
}

variable "gke_dws_default_cluster_region" {
  description = "Default GKE DWS cluster region (primary_region or secondary_region)"
  type        = string
  validation {
    condition     = var.gke_dws_default_cluster_region == "primary_region" || var.gke_dws_default_cluster_region == "secondary_region"
    error_message = "gke_dws_default_cluster_region must be set to primary_region or secondary_region"
  }
}

variable "gke_dws_default_cluster_compute_zones" {
  description = "GKE DWS default cluster compute zones"
  type        = list(string)
}

variable "gke_dws_secondary_cluster_enabled" {
  description = "Indicates if secondary GKE DWS cluster should be created (dev only)"
  type        = bool
  default     = false
}

variable "gke_dws_secondary_cluster_region" {
  description = "Secondary GKE DWS cluster region (primary_region or secondary_region)"
  type        = string
  validation {
    condition     = var.gke_dws_secondary_cluster_region == "primary_region" || var.gke_dws_secondary_cluster_region == "secondary_region"
    error_message = "gke_dws_secondary_cluster_region must be set to primary_region or secondary_region"
  }
}

variable "gke_dws_secondary_cluster_compute_zones" {
  description = "GKE DWS secondary cluster compute zones"
  type        = list(string)
}

variable "elastic_cloud_gcp_region" {
  description = "elastic cloud gcp region"
  type        = string
}

variable "union_ai_cloud_enabled" {
  description = "Indicates if union ai cloud should be enabled"
  type        = bool
}

variable "composer_cluster_enabled" {
  description = "Indicates if composer cluster should be enabled"
  type        = bool
}

variable "elasticsearch_cloud_api_key" {
  description = "elasticsearch cloud api key (copy the data out of secrets manager - elasticsearch_cloud_api_key - and place it in secrets.tfvars)"
  type        = string
  default     = ""
}

variable "datadog_api_key" {
  description = "datadog api key (copy the data out of secrets manager - datadog_api_key - and place it in secrets.tfvars)"
  type        = string
}

variable "datadog_app_key" {
  description = "datadog api key (copy the data out of secrets manager - datadog_app_key - and place it in secrets.tfvars)"
  type        = string
}

variable "aws_region" {
  description = "aws region"
  type        = string
}

variable "aws_account_id" {
  description = "aws account id"
  type        = string
  default     = ""
}

variable "aws_access_key" {
  description = "aws access key (copy the data out of secrets manager - aws_access_key - and place it in secrets.tfvars)"
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "aws access key (copy the data out of secrets manager - aws_access_key - and place it in secrets.tfvars)"
  type        = string
  default     = ""
}

variable "pen_tester_bastion_host_enabled" {
  description = "Indicates if pen tester bastion host should be enabled"
  type        = bool
  default     = false
}

variable "pen_tester_src_ip_address" {
  description = "IP address of the pen tester"
  type        = string
  default     = null
}

variable "pen_tester_ssh_pub_key" {
  description = "Pen tester ssh public key"
  type        = string
  default     = null
}

variable "temporal_host" {
  description = "Temporal host"
  type        = string
}

variable "temporal_namespace" {
  description = "Temporal namespace"
  type        = string
}

variable "text_embed_endpoint_url" {
  description = "Text embed endpoint URL"
  type        = string
}

# ── CircleCI Workload Identity Federation ────────────────────────────────────
# Required to create the CircleCI OIDC provider in circleci_wif.tf.
# Find these values at:
#   circleci_org_id     → CircleCI → Organization Settings → Overview
#   circleci_project_id → CircleCI → Project Settings → Overview (this repo)
# Add both to environments/<env>/terraform.tfvars.
# Leave as empty strings to skip WIF provider creation (resources are conditional).
variable "circleci_org_id" {
  description = "CircleCI organization ID (UUID) — used to configure the OIDC WIF provider"
  type        = string
  default     = ""
}

variable "circleci_project_id" {
  description = "CircleCI project ID (UUID) for the terraform repository — restricts WIF access to this project"
  type        = string
  default     = ""
}
