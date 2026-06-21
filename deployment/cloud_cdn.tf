resource "google_compute_managed_ssl_certificate" "spiffy_cdn_ssl_cert" {
  project = var.project_id
  lifecycle {
    create_before_destroy = true
  }
  name = var.environment == "prod" ? "spiffy-cdn-domain-cert" : "dev-spiffy-frontend-cdn-cert"
  managed {
    domains = var.environment == "prod" ? ["cdn.spiffy.ai"] : ["frontend-cdn.dev.spiffy.ai"]
  }
}

resource "google_compute_backend_bucket" "spiffy-chat-frontend-cdn-backend-bucket" {
  name             = var.environment == "prod" ? "spiffy-chat-frontend-cdn" : "frontend-${var.environment}"
  description      = "Spiffy Chat Frontend CDN"
  compression_mode = "AUTOMATIC"
  bucket_name      = google_storage_bucket.spiffy-chat-frontend.name
  enable_cdn       = true
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    request_coalescing           = true
    signed_url_cache_max_age_sec = 0
    # max_ttl                    = 21600
    # client_ttl                 = 900
  }
  timeouts {}
}

resource "google_compute_url_map" "spiffy-cdn-load-balancer-url-map" {
  name            = var.environment == "prod" ? "spiffy-cdn-load-balancer" : "frontend-dev-cdn-balancer"
  default_service = google_compute_backend_bucket.spiffy-chat-frontend-cdn-backend-bucket.id
  dynamic "host_rule" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      hosts = ["*"]
      path_matcher = "path-matcher-default"
    }
  }
  dynamic "path_matcher" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      name            = "path-matcher-default"
      default_service = google_compute_backend_bucket.spiffy-chat-frontend-cdn-backend-bucket.id
      path_rule {
        paths = ["/spiffy-commerce-chat/*"]
        service = google_compute_backend_bucket.spiffy-chat-frontend-cdn-backend-bucket.id
      }
    }
  }
}

# Create HTTP target proxy
resource "google_compute_target_http_proxy" "spiffy-cdn-load-balancer-http-proxy" {
  name    = var.environment == "prod" ? "spiffy-cdn-load-balancer-http-proxy" : "frontend-dev-cdn-balancer-target-proxy"
  url_map = google_compute_url_map.spiffy-cdn-load-balancer-url-map.id
}

resource "google_compute_target_https_proxy" "spiffy-cdn-load-balancer-https-proxy" {
  name    = var.environment == "prod" ? "spiffy-cdn-load-balancer-https-proxy" : "frontend-dev-cdn-balancer-target-proxy-2"
  url_map = google_compute_url_map.spiffy-cdn-load-balancer-url-map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.spiffy_cdn_ssl_cert.id]
}

# Reserve IP address
resource "google_compute_global_address" "spiffy-cdn-load-balancer-ipv4" {
  name       = var.environment == "prod" ? "spiffy-cdn-load-balancer-ipv4" : "public-ip-addr-frontend-cdn"
  ip_version = "IPV4"
}

resource "google_compute_global_address" "spiffy-cdn-load-balancer-ipv6" {
  name       = var.environment == "prod" ? "spiffy-load-balancer-ipv6" : "spiffy-load-balancer-ipv6"
  ip_version = "IPV6"
}

# Create forwarding rule
resource "google_compute_global_forwarding_rule" "spiffy-cdn-load-balancer-port-80-forwarding-rule-ipv4" {
  name                  = var.environment == "prod" ? "spiffy-cdn-load-balancer-port-80-forwarding-rule-ipv4" : "frontend-dev-cdn-balancer-forwarding-rule-ipv4"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  ip_version            = null
  target                = google_compute_target_http_proxy.spiffy-cdn-load-balancer-http-proxy.id
  ip_address            = google_compute_global_address.spiffy-cdn-load-balancer-ipv4.id
}

resource "google_compute_global_forwarding_rule" "spiffy-cdn-load-balancer-port-80-forwarding-rule-ipv6" {
  name                  = var.environment == "prod" ? "spiffy-cdn-load-balancer-port-80-forwarding-rule-ipv6" : "frontend-dev-cdn-balancer-forwarding-rule-ipv6"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  ip_version            = null
  target                = google_compute_target_http_proxy.spiffy-cdn-load-balancer-http-proxy.id
  ip_address            = google_compute_global_address.spiffy-cdn-load-balancer-ipv6.id
}

resource "google_compute_global_forwarding_rule" "spiffy-cdn-load-balancer-port-443-forwarding-rule-ipv4" {
  name                  = var.environment == "prod" ? "spiffy-cdn-load-balancer-port-443-forwarding-rule-ipv4" : "frontend-cdn"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.spiffy-cdn-load-balancer-https-proxy.id
  ip_address            = google_compute_global_address.spiffy-cdn-load-balancer-ipv4.id
}

resource "google_compute_global_forwarding_rule" "spiffy-cdn-load-balancer-port-443-forwarding-rule-ipv6" {
  name                  = var.environment == "prod" ? "spiffy-cdn-load-balancer-port-443-forwarding-rule-ipv6" : "frontend-cdn-ipv6"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.spiffy-cdn-load-balancer-https-proxy.id
  ip_address            = google_compute_global_address.spiffy-cdn-load-balancer-ipv6.id
}