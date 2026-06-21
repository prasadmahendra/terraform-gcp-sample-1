locals {
  rebrand_dns_root     = "envive.ai"
  rebrand_dns_name     = var.environment == "prod" ? "${local.rebrand_dns_root}." : "${var.environment}.${local.rebrand_dns_root}."
  pre_rebrand_dns_root = "spiffy.ai"
  pre_rebrand_dns_name = var.environment == "prod" ? "${local.pre_rebrand_dns_root}." : "${var.environment}.${local.pre_rebrand_dns_root}."
}

resource "google_dns_managed_zone" "public-zone-envive" {

  depends_on = [google_project_service.all]
  name        = "public-zone-envive"
  project     = var.project_id
  dns_name    = local.rebrand_dns_name
  description = "${var.environment} public envive.ai dns zone"
  labels = {
    env = var.environment
  }
  visibility = "public"
  cloud_logging_config {
    enable_logging = false
  }
}

resource "google_dns_managed_zone" "private-zone-envive" {

  depends_on = [google_project_service.all]
  name        = "private-zone-envive"
  project     = var.project_id
  dns_name    = local.rebrand_dns_name
  description = "${var.environment} private dns zone"
  labels = {
    env = var.environment
  }
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc-deployment.id
    }
    dynamic "gke_clusters" {
      for_each = module.container-cluster-default
      content {
        gke_cluster_name = gke_clusters.value.cluster_id
      }
    }
  }
  cloud_logging_config {
    enable_logging = false
  }
}

# Delegate dev.envive.ai. NS records to the dev environment dns zone
resource "google_dns_record_set" "delegate_dev_subdomain_to_dev_project_dns_zone_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "dev.${local.rebrand_dns_root}."
  type         = "NS"
  ttl          = 300
  rrdatas      = data.terraform_remote_state.dev.outputs.google_dns_managed_envive_public_zone_name_servers
}

# Gsuite records for the company
resource "google_dns_record_set" "gsuite_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "${local.rebrand_dns_root}."
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

resource "google_dns_record_set" "gsuite_marketing_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "marketing.${local.rebrand_dns_root}."
  type         = "MX"
  ttl          = 3600
  rrdatas = [
    "1 smtp.google.com."
  ]
}

# Site verification TXT records for gsuite
resource "google_dns_record_set" "gsuite_site_verification_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "${local.rebrand_dns_root}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"google-site-verification=IKPXUfjnJ6cGuYQCE59r8smxFdfssAoSGnCuOyqPw0k\"",
    "\"v=spf1 include:_spf.google.com include:46513108.spf02.hubspotemail.net -all\"",
    "\"google-site-verification=oXi3eR26LQiwAhpehsnAWVbVEstHhgn3QJLtXgOsq9I\"",
    "\"asv_domain=fcd928f795028e98be3f1923071304be\""
  ]
}

resource "google_dns_record_set" "gsuite_dkim_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "google._domainkey.${local.rebrand_dns_root}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCaGMtGSXniLARvL20dQT9XqUlfbuC8+88YCMOBgKVLP0PS3ewrnLuy4I4YjL+wjhX3pcjJb6Nu9xyBCuiHfK843H/lmasge8Ni2XrqtxLwgvw9hMa13TI5fd90W9469NhI+BsCM1wGVMAr+OrFlm2sDHOJqJdD+LdzckA42lBfOwIDAQAB\""
  ]
}


resource "google_dns_record_set" "gsuite_site_verification_envive_dmarc" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "_dmarc.${local.rebrand_dns_root}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"v=DMARC1; p=reject; rua=mailto:postmaster@${local.rebrand_dns_root}, mailto:dmarc@${local.rebrand_dns_root}; pct=100; adkim=s; aspf=s\"",
  ]
}

resource "google_dns_record_set" "webflow_verification_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "_webflow.${local.rebrand_dns_root}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"one-time-verification=e614911c-5477-4dba-9644-0ae26aa10fec\""
  ]
}

resource "google_dns_record_set" "marketing_verification_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "marketing.${local.rebrand_dns_root}."
  type         = "TXT"
  ttl          = 300
  rrdatas = [
    "\"google-site-verification=fzpGdmUl3_o4AgS89k_w799MkeCqyiMQgQtDtYyK9-w\"",
    "\"ips5k2gjmcwn.marketing.envive.ai.\"",
    "\"gv-6mtw7dgvedcnhr.dv.googlehosted.com\""
  ]
}


# A record for www.envive.ai
resource "google_dns_record_set" "www_envive_ai_a" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "www.${local.rebrand_dns_root}."
  type         = "A"
  ttl          = 300
  rrdatas = ["198.202.211.1"]
}

# CNAME = attractive-manatee.aploconnect.com for track.envive.ai
resource "google_dns_record_set" "track_envive_ai_cname" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "track.${local.rebrand_dns_root}."
  type         = "CNAME"
  ttl          = 300
  rrdatas = ["attractive-manatee.aploconnect.com."]
}

# A record for envive.ai (root domain)
resource "google_dns_record_set" "root_envive_ai_a" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "${local.rebrand_dns_root}."
  type         = "A"
  ttl          = 300
  rrdatas = ["198.202.211.1"]
}


# cname platform.envive.ai -> platform.spiffy.ai
resource "google_dns_record_set" "platform_envive_cname" {
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone.name
  name         = "platform.${local.pre_rebrand_dns_name}"
  type         = "CNAME"
  ttl          = 300
  rrdatas = [
    "platform.${local.rebrand_dns_name}"
  ]
}

resource "google_dns_record_set" "partners_envive_cname_partner_dashboard" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "partners.${local.rebrand_dns_name}"
  type         = "CNAME"
  ttl          = 300
  rrdatas = [
    "partnerdashboard.lassotech.com."
  ]
}


resource "google_dns_record_set" "partners_envive_cname_events" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "go.${local.rebrand_dns_name}"
  type         = "CNAME"
  ttl          = 300
  rrdatas = [
    "46513108.group8.sites.hubspot.net."
  ]
}

resource "google_dns_record_set" "hubspot_dkim_envive_a" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "hs1-46513108._domainkey.${local.rebrand_dns_root}."
  type         = "CNAME"
  ttl          = 300
  rrdatas = [
    "envive-ai.hs08a.dkim.hubspotemail.net.",
  ]
}

resource "google_dns_record_set" "hubspot_dkim_envive_b" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "hs2-46513108._domainkey.${local.rebrand_dns_root}."
  type         = "CNAME"
  ttl          = 300
  rrdatas = [
    "envive-ai.hs08b.dkim.hubspotemail.net."
  ]
}

# Discovery Engine A record
resource "google_dns_record_set" "discovery_engine_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on   = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "discovery-engine.${local.rebrand_dns_root}."
  type         = "A"
  ttl          = 300
  rrdatas      = ["185.158.133.1"]
}

# Lovable domain verification for Discovery Engine
resource "google_dns_record_set" "lovable_discovery_engine_verification_envive" {
  count        = var.environment == "prod" ? 1 : 0
  depends_on   = [google_dns_managed_zone.public-zone-envive]
  managed_zone = google_dns_managed_zone.public-zone-envive.name
  name         = "_lovable.discovery-engine.${local.rebrand_dns_root}."
  type         = "TXT"
  ttl          = 300
  rrdatas      = ["lovable_verify=e13f65602e9208c3103e0376cdcd50e55fc20aed9fff4116efea7fc680d615ec"]
}


