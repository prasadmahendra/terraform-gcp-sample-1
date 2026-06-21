locals {
  additional_domains = var.environment == "prod" ? [var.root_domain] : []
  additional_domains_v2 = var.environment == "prod" ? [var.root_domain, local.rebrand_dns_root] : []
}

resource "google_compute_managed_ssl_certificate" "spiffy_domain_ssl_cert_ex" {
  project  = var.project_id
  lifecycle {
    create_before_destroy = true
  }
  name     = "${var.environment}-spiffy-env-domain-cert"
  managed {
    domains = concat(["${var.environment}.${var.root_domain}"], local.additional_domains)
  }
}

resource "google_compute_managed_ssl_certificate" "spiffy_domain_ssl_cert_ex_v2" {
  project  = var.project_id
  lifecycle {
    create_before_destroy = true
  }
  name     = "${var.environment}-spiffy-env-domain-cert-v2"
  managed {
    domains = concat(["${var.environment}.${var.root_domain}", "${var.environment}.${local.rebrand_dns_root}"], local.additional_domains_v2)
  }
}