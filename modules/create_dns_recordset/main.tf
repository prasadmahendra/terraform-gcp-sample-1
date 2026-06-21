resource "google_dns_record_set" "google_dns_record_set" {
  count        = var.dns_zone.provider == "google" ? 1 : 0
  name         = var.name
  managed_zone = var.dns_zone.name
  type         = var.type
  ttl          = var.ttl
  rrdatas      = var.rrdatas
}

resource "aws_route53_record" "aws_route53_record" {
  count   = var.dns_zone.provider == "aws" ? 1 : 0
  name    = var.name
  type    = var.type
  ttl     = var.ttl
  records = var.rrdatas
  zone_id = var.dns_zone.name
}