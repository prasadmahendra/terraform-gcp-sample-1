variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in which the CloudRun service should be deployed"
  type        = string
}

variable "region" {
  description = "The region in which the CloudRun service should be deployed"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ipv4_enabled" {
  description = "Whether the instance should have a public IP"
  type        = bool
}

variable "additional_databases" {
  description = "additional databases to be created"
  type = list(object({
    name      = string
    charset   = string
    collation = string
  }))
  default = []
}

variable "additional_users" {
  description = "additional users to be created"
  type = list(object({
    name            = string
    password        = string
    random_password = bool
  }))
  default = []
}

variable "require_ssl_for_connections" {
  description = "Require SSL for connections"
  type        = bool
}

variable "ssl_mode_for_connections" {
  # https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#ssl_mode
  description = "SSL mode for connections"
  type        = string
}

variable "availability_type" {
  description = "The availability type of the Cloud SQL instance"
  type        = string
  validation {
    condition = contains([
      "REGIONAL", "ZONAL"
    ], var.availability_type)
    error_message = "Must be REGIONAL or ZONAL"
  }
}

variable "allowed_external_ip_range" {
  type        = string
  description = "The ip range to allow connecting from/to Cloud SQL"
}

variable "allowed_external_ip_range_name" {
  type        = string
  description = "The ip range to allow connecting from/to Cloud SQL (eg: 'app subnet')"
}

variable "enable_read_replicas" {
  description = "Enable read replicas"
  type        = bool
}

# vCPUs must be either 1 or an even number between 2 and 96.
variable "cpu_count" {
  description = "CPU count for the instance. vCPUs must be either 1 or an even number between 2 and 96."
  type        = number
}

#
# Memory must be:
# 0.9 to 6.5 GB per vCPU
# A multiple of 256 MB
# At least 3.75 GB (3840 MB)
#
variable "memory_size_gb" {
  description = "The amount of memory in GB"
  type        = number
}

variable "retained_backups" {
  description = "The number of retained backups (days or count etc based on retention_unit)"
  type        = number
}

variable "retention_unit" {
  description = "The unit of retention"
  type        = string
  validation {
    condition = contains([
      "COUNT", "RETENTION_UNIT_UNSPECIFIED"
    ], var.retention_unit)
    error_message = "Must be COUNT or RETENTION_UNIT_UNSPECIFIED"
  }
}

variable "default_db_name" {
  description = "The default database to create"
  type        = string
}

variable "default_db_user_name" {
  description = "The default database user name"
  type        = string
}

variable "default_db_password" {
  description = "The default database password"
  type        = string
}

variable "super_user_password" {
  description = "The super user password"
  type        = string
}

variable "authorized_networks" {
  description = "The list of external networks that are allowed to connect to the instance. In CIDR notation."
  type = list(object({
    name  = string
    value = string
  }))
}

variable "disk_autoresize_limit" {
  description = "The maximum size to which the disk can be automatically increased. If null, there is no limit."
  type        = number
}