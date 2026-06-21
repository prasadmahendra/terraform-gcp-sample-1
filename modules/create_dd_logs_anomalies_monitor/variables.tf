variable "environment" {
  description = "The environment (dev, prod etc)"
  type        = string
}

variable "monitor_name" {
  description = "The name of the monitor"
  type        = string
}

variable "service_name" {
  description = "The name of the service"
  type        = string
}

variable "additional_tags" {
  description = "Tags on the monitor"
  type = list(string)
  default = []
}

variable "priority" {
  description = "The priority of the monitor"
  type        = number
  default     = 3
}

variable "team" {
  description = "The team that owns the service"
  type        = string
}

variable "chapter" {
  description = "The chapter that owns the service"
  type        = string
}
