variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "agent_pool_name" {
  description = "The name of the agent pool"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "bandwidth_limit_mbps" {
  description = "The bandwidth limit in Mbps"
  type        = number
}

variable "agent_pool_description" {
  description = "The description of the agent pool"
  type        = string
}

variable "agent_pool_service_account_id_to_create" {
  description = "Service account to create"
  type        = string
}