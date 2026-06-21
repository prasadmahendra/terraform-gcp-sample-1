# WAF rules here: https://cloud.google.com/armor/docs/waf-rules
# CEL expressions here:
# https://cloud.google.com/secure-web-proxy/docs/cel-matcher-language-reference
#
# Load balancer logs with enforced policy details can be found in datadog:
# https://us5.datadoghq.com/logs?query=source%3Agcp.http.load.balancer%20env%3Aprod&agg_m=count&agg_m_source=base&agg_t=count&cols=host%2Cservice&fromUser=true&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=time%2Cdesc&viz=stream&from_ts=1740507876611&to_ts=1740508776611&live=true
#
# Rate limiting:
# https://us5.datadoghq.com/logs?query=%28source%3Agcp.http.load.balancer%20%28%40data.jsonPayload.enforcedSecurityPolicy.outcome%3ADENY%20OR%20%40data.jsonPayload.statusDetails%3A%2Asecurity_policy%2A%29%20%40http.status_code%3A%2A%20%40http.method%3A%2A%29%20AND%20%40http.method%3APOST%20%40http.status_code%3A429&agg_m=count&agg_m_source=base&agg_t=count&cols=host%2Cservice&fromUser=true&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=time%2Cdesc&viz=stream&from_ts=1740424929285&to_ts=1740511329285&live=true
#


# Create a Cloud Armor security policy
resource "google_compute_security_policy" "public_edge_compute_security_policy" {
  name     = "public-edge-compute-security-policy"
  type     = "CLOUD_ARMOR"
  provider = google-beta

  adaptive_protection_config {
    # https://cloud.google.com/armor/docs/adaptive-protection-auto-deploy
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
    auto_deploy_config {
      confidence_threshold        = 0.5
      load_threshold              = 0.8
      impacted_baseline_threshold = 0.01
      expiration_sec              = 7200
    }
  }

  # white-list packetlabs IP addresses
  # Add Packetlabs' IP for any WAF allowlist:
  # 35.182.86.97
  # 64.39.96.0/20 (Qualys Scanner)
  # 139.87.112.0/23 (Qualys Scanner)
  #
  # locust cloud IP addresses
  # 98.90.38.117
  # 34.199.222.136
  # 44.198.252.211
  # 44.208.98.77
  rule {
    action   = "allow"
    priority = "500"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["98.90.38.117", "34.199.222.136", "44.198.252.211", "44.208.98.77", "35.182.86.97"]
      }
    }
    description = "Allow Packetlabs IP addresses"
    preview = true # Pen testing is complete, so this set to true to noop the rule
  }

  # Block known bad user agents
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "request.headers['user-agent'].contains('bot') || request.headers['user-agent'].contains('crawler') || request.headers['user-agent'].contains('spider') || request.headers['user-agent'].contains('foregenix')"
      }
    }
    description = "Block known bot user agents"
  }

  # Block specified countries (example with Russia and North Korea)
  rule {
    action   = "deny(403)"
    priority = "2000"
    match {
      expr {
        expression = "origin.region_code == 'KP'"
      }
    }
    description = "Block specific countries"
  }

  # Block legitimate crawlers as well (Google, Bing, etc.)
  rule {
    action   = "deny(403)"
    priority = "3000"
    match {
      expr {
        # This is a simplified example. You should verify IP ranges for each search engine
        expression = "inIpRange(origin.ip, '66.249.64.0/19') || inIpRange(origin.ip, '64.233.160.0/19')"
      }
    }
    description = "Allow legitimate search engine crawlers"
  }

  # Enable Advanced protection features
  rule {
    action   = "deny(403)"
    priority = "4000"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('json-sqli-canary', {'sensitivity':0, 'opt_in_rule_ids': ['owasp-crs-id942550-sqli']}) || evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity':1})"
      }
    }
    description = "Enable protection against SQL injection"
    preview = true
  }

  # Bot Management Rule with Redirect
  rule {
    action   = "deny(403)"
    priority = "5000"
    match {
      expr {
        expression = "token.recaptcha_session.score < 0.5"
      }
    }
    description = "Deny suspicious bot traffic"
    preview = false
  }

  # Rate limiting
  rule {
    # Throttle: You can enforce a maximum request limit per client or across all clients by throttling individual
    # clients to a user-configured threshold.

    # Rate-based ban: You can rate limit requests that match a rule on a per-client basis and then temporarily ban
    # those clients for a configured period of time if they exceed a user-configured threshold.
    action   = "rate_based_ban"
    priority = "6000"
    match {
      expr {
        expression = "true"
      }
    }
    rate_limit_options {
      enforce_on_key = "IP"
      ban_duration_sec = 60
      rate_limit_threshold {
        count        = 2000
        interval_sec = 10
      }
      conform_action = "allow"
      exceed_action  = "deny(429)"
    }
    description = "Rate limiting rule"
    preview = false
  }

  # Default rule - allow all other traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }
}