# =============================================================================
# Global external Application Load Balancer (Layer 7) in front of the portal
#  * Serverless NEGs in both regions — automatic failover if a region is down
#  * Cloud Armor: OWASP SQLi/XSS rules + per-IP rate limiting
#  * Identity-Aware Proxy: only iap_members reach the app (zero trust, no VPN)
#  * Google-managed certificate (portal_domain, or <ip>.nip.io for the demo)
# =============================================================================

locals {
  lb     = var.enable_portal_lb ? 1 : 0
  domain = var.enable_portal_lb ? (var.portal_domain != "" ? var.portal_domain : "${google_compute_global_address.portal[0].address}.nip.io") : ""
}

resource "google_compute_global_address" "portal" {
  count   = local.lb
  project = local.project
  name    = "carenotes-portal-ip"
}

resource "google_compute_region_network_endpoint_group" "portal" {
  for_each = var.enable_portal_lb ? toset(local.regions) : toset([])

  project               = local.project
  name                  = "carenotes-portal-neg-${each.value}"
  region                = each.value
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.portal[each.value].name
  }
}

resource "google_compute_security_policy" "armor" {
  count       = local.lb
  project     = local.project
  name        = "carenotes-armor"
  description = "OWASP top-10 WAF rules and rate limiting for the CareNotes portal"

  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "SQL injection"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "deny(403)"
    priority    = 1001
    description = "Cross-site scripting"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action      = "rate_based_ban"
    priority    = 2000
    description = "100 requests/min per client IP, 5 minute ban"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = 300
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow (IAP still requires an authorized identity)"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

resource "google_compute_backend_service" "portal" {
  count = local.lb

  project               = local.project
  name                  = "carenotes-portal-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.armor[0].id

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.portal
    content {
      group = backend.value.id
    }
  }

  iap {
    enabled = true
  }

  # Serverless NEGs have no health checks: outlier detection ejects a failing region so
  # the load balancer fails over to the other one.
  outlier_detection {
    consecutive_errors           = 5
    enforcing_consecutive_errors = 100
    max_ejection_percent         = 50
    interval {
      seconds = 10
    }
    base_ejection_time {
      seconds = 60
    }
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "portal" {
  count           = local.lb
  project         = local.project
  name            = "carenotes-portal"
  default_service = google_compute_backend_service.portal[0].id
}

resource "google_compute_managed_ssl_certificate" "portal" {
  count   = local.lb
  project = local.project
  name    = "carenotes-portal-cert-${substr(md5(local.domain), 0, 6)}"

  managed {
    domains = [local.domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "portal" {
  count            = local.lb
  project          = local.project
  name             = "carenotes-portal-https"
  url_map          = google_compute_url_map.portal[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.portal[0].id]
}

resource "google_compute_global_forwarding_rule" "portal" {
  count                 = local.lb
  project               = local.project
  name                  = "carenotes-portal-https"
  target                = google_compute_target_https_proxy.portal[0].id
  ip_address            = google_compute_global_address.portal[0].id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# IAP calls Cloud Run with its own service agent.
resource "google_project_service_identity" "iap" {
  count    = local.lb
  provider = google-beta
  project  = local.project
  service  = "iap.googleapis.com"
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  for_each = var.enable_portal_lb ? toset(local.regions) : toset([])

  project  = local.project
  location = each.value
  name     = google_cloud_run_v2_service.portal[each.value].name
  role     = "roles/run.invoker"
  member   = google_project_service_identity.iap[0].member
}

resource "google_iap_web_backend_service_iam_member" "access" {
  for_each = var.enable_portal_lb ? toset(var.iap_members) : toset([])

  project             = local.project
  web_backend_service = google_compute_backend_service.portal[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.value
}
