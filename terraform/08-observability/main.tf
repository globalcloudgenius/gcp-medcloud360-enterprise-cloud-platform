# =============================================================================
# Stage 08 — Observability, detection and reliability (mc360-prj-observability)
#  * One metrics scope over every MedCloud360 project
#  * Log-based security detections on org-wide audit logs + alert policies
#  * Portal SLO (99% good requests, rolling 7 days) with burn-rate alerting
#  * Network Intelligence Center connectivity tests that prove hub-and-spoke isolation
#  * Operations dashboard
# =============================================================================

locals {
  obs     = var.projects.observability
  channel = data.terraform_remote_state.org.outputs.alert_channel_id
  sec_bkt = data.terraform_remote_state.org.outputs.security_log_bucket
  nets    = data.terraform_remote_state.network.outputs.networks

  monitored = ["network", "prod_app", "prod_data", "dev", "test"]

  # Log-based detections on the org-wide security log bucket.
  detections = {
    iam-policy-change = {
      title    = "IAM policy changed"
      severity = "WARNING"
      filter   = "protoPayload.methodName=\"SetIamPolicy\" AND severity!=\"ERROR\""
    }
    org-policy-change = {
      title    = "Organization policy changed"
      severity = "CRITICAL"
      filter   = "protoPayload.serviceName=\"orgpolicy.googleapis.com\" AND protoPayload.methodName=~\"(Create|Update|Delete)Policy\""
    }
    vpcsc-violation = {
      title    = "VPC Service Controls violation (data exfiltration attempt)"
      severity = "CRITICAL"
      filter   = "protoPayload.metadata.@type=\"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata\""
    }
    sa-key-attempt = {
      title    = "Service account key creation attempted"
      severity = "ERROR"
      filter   = "protoPayload.methodName=\"google.iam.admin.v1.CreateServiceAccountKey\""
    }
    firewall-change = {
      title    = "Firewall policy or rule changed"
      severity = "WARNING"
      filter   = "protoPayload.methodName=~\"(firewallPolicies|firewalls)\\\\.(insert|patch|delete|addRule|patchRule|removeRule)\""
    }
  }
}

resource "google_monitoring_monitored_project" "scope" {
  for_each = toset(local.monitored)

  metrics_scope = "locations/global/metricsScopes/${local.obs}"
  name          = var.projects[each.value]
}

resource "google_logging_metric" "detection" {
  for_each = local.detections

  project     = local.obs
  name        = "mc360/${each.key}"
  description = each.value.title
  bucket_name = local.sec_bkt
  filter      = each.value.filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "detection" {
  for_each = local.detections

  project               = local.obs
  display_name          = "[SEC] ${each.value.title}"
  combiner              = "OR"
  severity              = each.value.severity
  notification_channels = [local.channel]

  conditions {
    display_name = each.value.title
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.detection[each.key].name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Runbook: docs/runbooks/INCIDENT-RESPONSE.md. Investigate in the SIEM: ${var.projects.observability}.org_audit_siem."
    mime_type = "text/markdown"
  }
}

# SCC router writes one structured log line per HIGH/CRITICAL finding.
resource "google_logging_metric" "scc_finding" {
  project     = local.obs
  name        = "mc360/scc-high-finding"
  description = "HIGH/CRITICAL Security Command Center finding routed"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"scc-router\" AND jsonPayload.event=\"scc_finding\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "scc_finding" {
  project               = local.obs
  display_name          = "[SEC] Security Command Center HIGH/CRITICAL finding"
  combiner              = "OR"
  severity              = "ERROR"
  notification_channels = [local.channel]

  conditions {
    display_name = "New HIGH/CRITICAL finding"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.scc_finding.name}\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  documentation {
    content   = "Triage per docs/runbooks/SCC-REMEDIATION.md: fix in Terraform, add a guardrail, confirm INACTIVE."
    mime_type = "text/markdown"
  }
}

# --- Reliability: portal 5xx and SLO ---------------------------------------------------
resource "google_monitoring_alert_policy" "portal_5xx" {
  project               = local.obs
  display_name          = "[OPS] CareNotes portal 5xx responses"
  combiner              = "OR"
  severity              = "ERROR"
  notification_channels = [local.channel]

  conditions {
    display_name = "5xx > 5 in 5 minutes"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"carenotes-portal\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "0s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }
}

resource "google_monitoring_custom_service" "portal" {
  project      = local.obs
  service_id   = "carenotes-portal"
  display_name = "CareNotes portal (Cloud Run, 2 regions)"
}

resource "google_monitoring_slo" "portal_availability" {
  project             = local.obs
  service             = google_monitoring_custom_service.portal.service_id
  slo_id              = "availability-99"
  display_name        = "99% of portal requests succeed (rolling 7 days)"
  goal                = 0.99
  rolling_period_days = 7

  request_based_sli {
    good_total_ratio {
      good_service_filter  = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"carenotes-portal\" metric.label.\"response_code_class\"=\"2xx\""
      total_service_filter = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"carenotes-portal\""
    }
  }
}

resource "google_monitoring_alert_policy" "slo_burn" {
  project               = local.obs
  display_name          = "[SLO] Portal error budget burning fast"
  combiner              = "OR"
  severity              = "WARNING"
  notification_channels = [local.channel]

  conditions {
    display_name = "Burn rate > 10x over 1 hour"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.portal_availability.id}\", \"3600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "0s"
    }
  }
}

# --- Network Intelligence Center: prove the hub-and-spoke isolation ---------------------
resource "google_network_management_connectivity_test" "isolation" {
  for_each = {
    prod-to-hub = {
      desc = "EXPECT REACHABLE: edge spoke (prod) -> center spoke (hub)"
      src  = { ip = "10.42.0.50", net = "prod" }
      dst  = { ip = "10.40.0.10", net = "hub" }
    }
    prod-to-nonprod = {
      desc = "EXPECT UNREACHABLE: edge spoke (prod) -> edge spoke (nonprod), blocked by NCC STAR topology"
      src  = { ip = "10.42.0.50", net = "prod" }
      dst  = { ip = "10.41.0.10", net = "nonprod" }
    }
  }

  project     = var.projects.network
  name        = "mc360-${each.key}"
  description = each.value.desc
  protocol    = "TCP"

  source {
    ip_address = each.value.src.ip
    network    = local.nets[each.value.src.net].id
    project_id = var.projects.network
  }

  destination {
    ip_address = each.value.dst.ip
    port       = 443
    network    = local.nets[each.value.dst.net].id
    project_id = var.projects.network
  }
}

# --- Dashboard ------------------------------------------------------------------------
resource "google_monitoring_dashboard" "ops" {
  project = local.obs
  dashboard_json = jsonencode({
    displayName = "MedCloud360 CareNotes — operations and security"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width = 6, height = 4, xPos = 0, yPos = 0
          widget = {
            title = "Portal requests by response class"
            xyChart = { dataSets = [{
              timeSeriesQuery = { timeSeriesFilter = {
                filter      = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"carenotes-portal\""
                aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_RATE", crossSeriesReducer = "REDUCE_SUM", groupByFields = ["metric.label.\"response_code_class\""] }
              } }
              plotType = "STACKED_AREA"
            }] }
          }
        },
        {
          width = 6, height = 4, xPos = 6, yPos = 0
          widget = {
            title = "Portal p95 latency"
            xyChart = { dataSets = [{
              timeSeriesQuery = { timeSeriesFilter = {
                filter      = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"carenotes-portal\""
                aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_PERCENTILE_95", crossSeriesReducer = "REDUCE_MAX" }
              } }
              plotType = "LINE"
            }] }
          }
        },
        {
          width = 6, height = 4, xPos = 0, yPos = 4
          widget = {
            title = "HL7 gateway CPU (MIG, 3 zones)"
            xyChart = { dataSets = [{
              timeSeriesQuery = { timeSeriesFilter = {
                filter      = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\" metadata.user_labels.\"role\"=\"hl7-gateway\""
                aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN" }
              } }
              plotType = "LINE"
            }] }
          }
        },
        {
          width = 6, height = 4, xPos = 6, yPos = 4
          widget = {
            title = "HL7 messages published to Pub/Sub"
            xyChart = { dataSets = [{
              timeSeriesQuery = { timeSeriesFilter = {
                filter      = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" resource.type=\"pubsub_topic\" resource.label.\"topic_id\"=\"hl7-adt\""
                aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_RATE", crossSeriesReducer = "REDUCE_SUM" }
              } }
              plotType = "LINE"
            }] }
          }
        },
        {
          width = 12, height = 4, xPos = 0, yPos = 8
          widget = {
            title = "Security detections (org audit logs)"
            xyChart = { dataSets = [for k, m in google_logging_metric.detection : {
              timeSeriesQuery = { timeSeriesFilter = {
                filter      = "metric.type=\"logging.googleapis.com/user/${m.name}\""
                aggregation = { alignmentPeriod = "300s", perSeriesAligner = "ALIGN_SUM" }
              } }
              plotType       = "STACKED_BAR"
              legendTemplate = k
            }] }
          }
        },
      ]
    }
  })
}

# --- Domain-restricted sharing (the 14th org policy) -------------------------------------
# Applied last: Google-managed service agents granted in stages 01-06 (log sink writers,
# Pub/Sub, IAP, SCC) already hold their roles. The constraint is not retroactive; from here
# on only identities from this Cloud Identity customer can be granted access.
resource "google_org_policy_policy" "domain_restriction" {
  count = var.enable_domain_restriction ? 1 : 0

  name   = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [var.customer_id]
      }
    }
  }
}
