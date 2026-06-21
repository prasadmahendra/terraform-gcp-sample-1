variable "environment" {
  description = "Name of environment (dev, test, prod)"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

variable "project_id" {
  description = "gc project id"
  type        = string
}

variable "service_name" {
  description = "The name of the CloudRun service"
  type        = string
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
}

variable "docker_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "domain_name_public" {
  description = "Domain name for the service e.g: feeltheagi.dev.spiffy.ai"
  type        = string
}

variable "dns_zone_name_public" {
  description = "The DNS zone name (public) to use for the CloudRun service"
  type        = object({
    name     = string
    provider = string
  })
}

variable "dns_zone_name_private" {
  description = "The DNS zone name (private) to use for the CloudRun service"
  type        = string
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = object({
    secret  = string
    version = string
  })
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com, datadoghq.eu, us3.datadoghq.com, etc.)"
  type        = string
}

variable "datadog_trace_enabled" {
  description = "Enable Datadog APM"
  type        = bool
}