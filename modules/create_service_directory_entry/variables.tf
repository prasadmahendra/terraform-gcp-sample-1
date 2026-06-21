variable "service_directory_namespace_id" {
  description = "The ID of the service directory namespace"
  type        = string
}

variable "ip_address" {
  description = "The IP address of the service"
  type        = string
}

variable "environment" {
  description = "The environment of the service"
  type        = string
}

variable "region" {
  description = "The region of the service"
  type        = string
}

variable "port" {
  description = "The port of the service"
  type        = number
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "project_id" {
  description = "The ID of the project"
  type        = string
}

variable "project_number" {
  description = "The number of the project"
  type        = string
}

variable "vpc_name" {
  description = "Name of the vpc network"
  type        = string
}