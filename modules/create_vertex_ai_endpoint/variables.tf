variable "environment" {
  description = "Environment ID"
  type        = string
}

variable "endpoint_name" {
  description = "The name of the Vertex AI endpoint"
  type        = string
}

variable "endpoint_display_name" {
  description = "The display name of the Vertex AI endpoint"
  type        = string
}

variable "endpoint_description" {
  description = "The description of the Vertex AI endpoint"
  type        = string
}

variable "project_id" {
  description = "The ID of the project to setup Union.AI"
  type        = string
}

variable "project_number" {
  description = "The number of the project to setup Union.AI"
  type        = string
}

variable "vpc_network_id" {
  description = "The network to use for the Vertex AI endpoint"
  type        = string
}

variable "vpc_network_name" {
  description = "The name of the network to use for the Vertex AI endpoint"
  type        = string
}

variable "region" {
  description = "The region to use for the Vertex AI endpoint"
  type        = string
}