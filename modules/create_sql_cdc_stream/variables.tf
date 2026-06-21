variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in which the datastream service should be deployed"
  type        = string
}

variable "region" {
  description = "The region in which the datastream service should be deployed"
  type        = string
}

variable "vpc_id" {
    description = "The ID of the VPC in which datastream should connect to"
    type        = string
}

variable "cidr_block_for_datastream_vpc" {
    description = "CIDR block for datastream vpc"
    type        = string
}

variable "enable_datastream" {
  description = "Enable Datastream"
  type = object({
    enabled = bool
    database_name = string
    database_hostname = string
    database_hostname_port = number
    database_username = string
    database_username_password = string
    destination = list(object({
      type = string # gcs or bq or pubsub etc
      display_name = string
      id = string
      bucket_name = string
      bucket_root_path = string
    }))
  })
  default = {
    database_name = ""
    database_hostname = ""
    database_hostname_port = 0
    database_username = ""
    database_username_password = ""
    enabled = false
    destination = []
  }
}
