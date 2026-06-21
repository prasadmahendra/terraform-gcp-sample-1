variable "environment" {
  default = "central"
  type    = string
}

variable "org_id" {
  description = "gcp organization id"
  type        = string
}

variable "org_name" {
  description = "organization name"  # ex: spiffy
  type        = string
}

variable "project_name" {
  description = "gc project name"
  type        = string
}

variable "project_id" {
  description = "gc project id"
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

variable "region" {
  description = "gcp region"
  type        = string
}

variable "cidr_block" {
  description = "cidr block for master"
  type        = string
}

variable "vpn_client_cidr_block" {
  description = "cidr block for vpn"
  type        = string
}

variable "dev_cidr_block" {
  description = "cidr block for dev"
  type        = string
}

variable "dev_training_cidr_block" {
  description = "cidr block for dev_training"
  type        = string
}

variable "prod_cidr_block" {
  description = "cidr block for prod"
  type        = string
}

variable "prod_training_cidr_block" {
  description = "cidr block for prod_training"
  type        = string
}

variable "bi_prod_cidr_block" {
  description = "cidr block for bi_prod"
  type        = string
}

variable "bi_dev_cidr_block" {
  description = "cidr block for bi_dev"
  type        = string
}

variable "datadog_api_key" {
  description = "datadog api key"
  type        = string
  sensitive   = true
  # central reads this from Secret Manager via data source; variable kept for
  # compatibility with secrets.tfvars used in local runs.
  default = ""
}

variable "datadog_app_key" {
  description = "datadog app key"
  type        = string
  # central reads this from Secret Manager via data source; variable kept for
  # compatibility with secrets.tfvars used in local runs.
  default = ""
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
