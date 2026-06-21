variable "environment" {
  description = "The environment tag"
  type        = string
}

variable "project_id" {
  description = "The ID of the project in GCP"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

variable "gateway_id" {
  description = "The ID of the gateway"
  type        = string
}

variable "api_id" {
  description = "The ID of the API"
  type        = string
}

variable "openapi_documents_contents_b64encoded" {
  description = "The contents of the OpenAPI document in base64 encoded format"
  type        = string
}
