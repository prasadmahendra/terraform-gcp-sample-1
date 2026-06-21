variable "type" {
  description = "Record type (ex: A, NS, MX, TXT etc)"
  type        = string
}

variable "name" {
  description = "Record name (ex: www, @, subdomain etc)"
  type        = string
}

variable "rrdatas" {
  description = "Record data"
  type        = list(string)
}

variable "ttl" {
  description = "TTL for the record in seconds"
  type        = number
}

variable "dns_zone" {
  description = "DNS zone to use"
  type        = object({
    name     = string
    provider = string
  })
}