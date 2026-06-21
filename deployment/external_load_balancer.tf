# Based on
# https://github.com/terraform-google-modules/terraform-google-lb-http/tree/v10.1.0/examples/traffic-director
# https://cloud.google.com/load-balancing/docs/backend-service
# https://cloud.google.com/traffic-director/docs/overview?hl=en&authuser=1
# https://cloud.google.com/traffic-director/docs/prepare-gateway?hl=en&authuser=1

locals {
  traffic_director_name         = "${var.environment}-traffic-director"
  traffic_director_url_map_name = "${var.environment}-traffic-director-urlmap"
}

#module "external-load-balancer" {
#  count = 0
#  source  = "terraform-google-modules/lb-http/google"
#  version = "~> 10.0"
#
#  name           = local.traffic_director_name
#  project        = var.project_id
#  create_address = true
#
#  load_balancing_scheme = "EXTERNAL"
#  network               = google_compute_network.vpc-deployment.self_link
#  #address               = "0.0.0.0"
#  firewall_networks     = []
#  url_map               = google_compute_url_map.external_loadbalancer_urlmap.self_link
#  ssl                   = false
#  ssl_certificates      = [] #[google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert.self_link]
#  https_redirect        = false
#
#  backends = {
#    default = {
#      protocol                        = "HTTP"
#      port                            = 80
#      port_name                       = "http"
#      timeout_sec                     = 30
#      connection_draining_timeout_sec = 0
#      enable_cdn                      = false
#
#      health_check = {
#        check_interval_sec  = 15
#        timeout_sec         = 15
#        healthy_threshold   = 4
#        unhealthy_threshold = 4
#        request_path        = "/health"
#        port                = 80
#        logging             = true
#      }
#
#      log_config = {
#        enable = false
#      }
#
#      # leave blank, NEGs are dynamically added to the lb via autoneg
#      groups = [
#        #        {
#        #          # Each node pool instance group should be added to the backend.
#        #          group                        = "http://34.82.180.215"
#        #          balancing_mode               = null
#        #          capacity_scaler              = null
#        #          description                  = null
#        #          max_connections              = null
#        #          max_connections_per_instance = null
#        #          max_connections_per_endpoint = null
#        #          max_rate                     = null
#        #          max_rate_per_instance        = null
#        #          max_rate_per_endpoint        = null
#        #          max_utilization              = null
#        #        },
#      ]
#
#      iap_config = {
#        enable = false
#      }
#    }
#  }
#}

#resource "google_compute_url_map" "external_loadbalancer_urlmap" {
#
#  name            = local.traffic_director_url_map_name
#  description     = "Traffic Director URL Map"
#  default_service = module.llm-inference-service.compute_backend_service_id
#
#  host_rule {
#    hosts        = ["*"]
#    path_matcher = "all-paths"
#  }
#
#  path_matcher {
#    name            = "all-paths"
#    default_service = module.llm-inference-service.compute_backend_service_id
#
#    route_rules {
#      priority = 1
#      service  = module.llm-inference-service.compute_backend_service_id
#      match_rules {
#        prefix_match = "/nwac"
#      }
#    }
#  }
#}

#resource "google_compute_global_address" "external_loadbalancer_compute_global_address" {
#  name = "${var.environment}-external-lb-ip"
#}

#resource "google_compute_target_http_proxy" "external_loadbalancer_compute_target_http_proxy" {
#  name    = "${var.environment}-external-lb-target-http-proxy"
#  url_map = google_compute_url_map.external_loadbalancer_urlmap.self_link
#}

#resource "google_compute_target_https_proxy" "external_loadbalancer_compute_target_https_proxy" {
#  project          = var.project_id
#  name             = "${var.environment}-external-lb-target-https-proxy"
#  url_map          = google_compute_url_map.external_loadbalancer_urlmap.self_link
#  ssl_certificates = [google_compute_managed_ssl_certificate.spiffy_domain_ssl_cert.self_link]
#}

# https://cloud.google.com/traffic-director/docs/load-balancing?authuser=1&hl=en
# Traffic director => Global forwarding rule (INTERNAL_SELF_MANAGED) => Target HTTP Proxy => URL Map => Backend Service => ...
# Backend Service => Service Dir/GKE etc ...
# Backend Service => Health Check
#resource "google_compute_global_forwarding_rule" "external_loadbalancer_compute_global_forwarding_rule" {
#  name                  = "${var.environment}-external-lb-fwding-rule"
#  target                = google_compute_target_http_proxy.external_loadbalancer_compute_target_http_proxy.self_link
#  ip_address            = google_compute_global_address.external_loadbalancer_compute_global_address.address
#  #ip_address            = "0.0.0.0"
#  #load_balancing_scheme = "INTERNAL_SELF_MANAGED"
#  network               = google_compute_network.vpc-deployment.self_link
#  port_range            = "80"
#}

#resource "google_compute_backend_service" "home" {
#  name        = "home"
#  port_name   = "http"
#  protocol    = "HTTP"
#  timeout_sec = 10
#
#  health_checks = [google_compute_health_check.default.id]
#  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
#}
#
#resource "google_compute_health_check" "default" {
#  name               = "health-check"
#  http_health_check {
#    port = 80
#  }
#}