locals {
  dns_name = var.environment == "prod" ? "${var.root_domain}." : "${var.environment}.${var.root_domain}."
}

resource "google_dns_managed_zone" "public-zone" {

  depends_on = [google_project_service.all]
  name        = "public-zone"
  project     = var.project_id
  dns_name    = local.dns_name
  description = "${var.environment} public dns zone"
  labels = {
    env = var.environment
  }
  visibility = "public"
  cloud_logging_config {
    enable_logging = false
  }
}


resource "google_dns_managed_zone" "private-zone" {

  depends_on = [google_project_service.all]
  name        = "private-zone"
  project     = var.project_id
  dns_name    = local.dns_name
  description = "${var.environment} private dns zone"
  labels = {
    env = var.environment
  }
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc-deployment.id
    }
    # These conflict with DNS zones created and managed by GKE clusters unfortunately!
    # dynamic "gke_clusters" {
    #   for_each = module.container-cluster-default
    #   content {
    #     gke_cluster_name = gke_clusters.value.cluster_id
    #   }
    # }
  }
  cloud_logging_config {
    enable_logging = false
  }
}

resource "google_dns_managed_zone" "service_directory_zone" {

  count       = 1
  depends_on = [google_project_service.all]
  provider    = google-beta
  name        = "service-directory-zone"
  project     = var.project_id
  dns_name    = "services.${var.environment}.${var.root_domain}."
  description = "Private DNS Service Directory Zone"
  visibility  = "private"
  service_directory_config {
    namespace {
      namespace_url = google_service_directory_namespace.service_directory_namespace_backend_apps.id
    }
  }
  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc-deployment.id
    }
    # These conflict with DNS zones created and managed by GKE clusters unfortunately!
    # dynamic "gke_clusters" {
    #   for_each = module.container-cluster-default
    #   content {
    #     gke_cluster_name = gke_clusters.value.cluster_id
    #   }
    # }
  }
  cloud_logging_config {
    enable_logging = false
  }
}

# Delegate dev.spiffy.ai. NS records to the dev environment dns zone
resource "google_dns_record_set" "delegate_dev_subdomain_to_dev_project_dns_zone" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "dev.${var.root_domain}."
  type         = "NS"
  ttl          = 300
  rrdatas      = data.terraform_remote_state.dev.outputs.google_dns_managed_public_zone_name_servers
}

# Gsuite records for the company
resource "google_dns_record_set" "gsuite" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "${var.root_domain}."
  type         = "MX"
  ttl          = 3600
  rrdatas = [
    "1 aspmx.l.google.com.",
    "5 alt1.aspmx.l.google.com.",
    "5 alt2.aspmx.l.google.com.",
    "10 alt3.aspmx.l.google.com.",
    "10 alt4.aspmx.l.google.com."
  ]
}

# Site verification TXT records for gsuite
resource "google_dns_record_set" "gsuite_site_verification" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "${var.root_domain}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"slack-domain-verification=zoR5s93L2ptgPMbltXcGNbcJG8ZyPqoI3W68VM7Y\"",
    "\"google-site-verification=L8imegN7VJxT2I6nI3csHmzaemYxXh064tn0dnaORbk\"",
    "\"google-site-verification=c6kgCcCNrLTzZxMoh5OnG9rRBgaXwmqkwph-WiAHy0w\"",
    "\"v=spf1 a mx include:_spf.google.com ~all\"",
    "\"google-site-verification=e3TiHYkxXyY9j2tswQj0FkvHKfXnJzgcHQoxFThjiSY\"",
    "\"asv_domain=fcd928f795028e98be3f1923071304be\""
  ]
}

resource "google_dns_record_set" "gsuite_dkim" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "google._domainkey.${var.root_domain}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCOH6BTvbNnhrfwm7nq1kRT+pUYuVgbLVKpeT7o+9uYVkvUy9oK4FWjTrJL4Zr/qa3+\"",
    "\"yRjSVEyixiMJMHkcgt9fkIDbAeUtNWswFsbh4B4g9rxBUvJPsc1RsI23LEJbnS+a7ByIV7NDDX51eUB+FXocd2jCO6gfxsDzabE3jPnbHQIDAQAB\""
  ]
}

resource "google_dns_record_set" "gsuite_site_verification_dmarc" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "_dmarc.${var.root_domain}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"v=DMARC1; p=none; rua=mailto:postmaster@${var.root_domain}, mailto:dmarc@${var.root_domain}; pct=100; adkim=s; aspf=s\"",
  ]
}

# Records for webflow public facing site
resource "google_dns_record_set" "public_facing_website_cname" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "www.${var.root_domain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["proxy-ssl.webflow.com."]
}

# Records for webflow public facing site
resource "google_dns_record_set" "public_facing_website_arecs" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "${var.root_domain}."
  type         = "A"
  ttl          = 300
  rrdatas = [
    "75.2.70.75",
    "99.83.190.102"
  ]
}

# Records for webflow public facing site
resource "google_dns_record_set" "public_facing_website_webflow_onetime_verification" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "_webflow.${var.root_domain}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "one-time-verification=b4e5fbaa-398b-483e-8c4c-e9f95780b41c"
  ]
}

# frontend-cdn.dev.spiffy.ai.
resource "google_dns_record_set" "spiffy_cdn" {
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = var.environment == "prod" ? "cdn.${local.dns_name}" : "frontend-cdn.${local.dns_name}"
  type         = "A"
  ttl          = 300
  rrdatas = [
    google_compute_global_address.spiffy-cdn-load-balancer-ipv4.address
  ]
}

# status page
# CNAME	status.spiffy.ai	l1x1ld09m39g.stspg-customer.com
resource "google_dns_record_set" "status_page" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "status.${var.root_domain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["l1x1ld09m39g.stspg-customer.com."]
}

# AWS Route53 public zone for prod
resource "aws_route53_zone" "public-zone" {
  count = var.environment == "prod" ? 1 : 0
  depends_on = [google_project_service.all]
  name  = local.dns_name
}

# Delegate dev.spiffy.ai. NS records to the dev environment dns zone
resource "aws_route53_record" "delegate_dev_subdomain_to_dev_project_dns_zone" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = "dev.${var.root_domain}."
  type    = "NS"
  ttl     = "300"
  records = data.terraform_remote_state.dev.outputs.google_dns_managed_public_zone_name_servers
}

# Gsuite records for the company
resource "aws_route53_record" "gsuite" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = "${var.root_domain}."
  type    = "MX"
  ttl     = "3600"
  records = [
    "1 aspmx.l.google.com.",
    "5 alt1.aspmx.l.google.com.",
    "5 alt2.aspmx.l.google.com.",
    "10 alt3.aspmx.l.google.com.",
    "10 alt4.aspmx.l.google.com."
  ]
}

# Site verification TXT records for gsuite
resource "aws_route53_record" "gsuite_site_verification" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = "${var.root_domain}."
  type    = "TXT"
  ttl     = "300"
  records = [
    "google-site-verification=L8imegN7VJxT2I6nI3csHmzaemYxXh064tn0dnaORbk",
    "google-site-verification=c6kgCcCNrLTzZxMoh5OnG9rRBgaXwmqkwph-WiAHy0w",
    "v=spf1 a mx include:_spf.google.com ~all"
  ]
}

# Records for webflow public facing site
resource "aws_route53_record" "public_facing_website_cname" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = "www.${var.root_domain}."
  type    = "CNAME"
  ttl     = "300"
  records = ["proxy-ssl.webflow.com"]
}

# Records for webflow public facing site
resource "aws_route53_record" "public_facing_website_arecs" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = var.root_domain
  type    = "A"
  ttl     = "300"
  records = [
    "75.2.70.75",
    "99.83.190.102"
  ]
}

# Records for webflow public facing site
resource "aws_route53_record" "public_facing_website_webflow_onetime_verification" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = "_webflow.${var.root_domain}."
  type    = "TXT"
  ttl     = "300"
  records = [
    "one-time-verification=b4e5fbaa-398b-483e-8c4c-e9f95780b41c"
  ]
}

# Records for cdn
resource "aws_route53_record" "spiffy_cdn" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = aws_route53_zone.public-zone[0].zone_id
  name    = var.environment == "prod" ? "cdn.${local.dns_name}" : "frontend-cdn.${local.dns_name}"
  type    = "A"
  ttl     = "300"
  records = [
    google_compute_global_address.spiffy-cdn-load-balancer-ipv4.address
  ]
}

# Asana TXT record for domain verification
resource "google_dns_record_set" "asana_domain_verification" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "${var.root_domain}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "asv=e3dfd8e0ede120fed308268f5d668171"
  ]
}