variable "environment" {
  description = "The environment (dev, prod etc)"
  type        = string
}

variable "project_id" {
  description = "The project id"
  type        = string
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "tags" {
  description = "Tags on the cluster"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "gcp region"
  type        = string
}
