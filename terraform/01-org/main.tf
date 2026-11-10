# =============================================================================
# Stage 01 — Organization governance
#  * APIs every later stage needs, per project
#  * 13 organization policies at the root + sandbox exception + custom constraint
#    (the 14th, domain-restricted sharing, is applied LAST in stage 08 so the Google-managed
#     service agents granted by stages 01-06 are in place before it is enforced)
#  * Resource tags (environment, data class) bound to the projects
#  * Org hierarchical firewall baseline
#  * Central audit logging: 7-year GCS bucket, BigQuery SIEM, security log bucket
#  * Data Access audit logs on the PHI project
#  * Budgets with alerts on every project
# =============================================================================

data "google_project" "p" {
  for_each   = var.projects
  project_id = each.value
}

locals {
  org_parent = "organizations/${var.org_id}"

  project_apis = {
    network = [
      "compute.googleapis.com", "dns.googleapis.com", "networkconnectivity.googleapis.com",
      "networkmanagement.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com",
    ]
    prod_app = [
      "aiplatform.googleapis.com", "artifactregistry.googleapis.com", "binaryauthorization.googleapis.com",
      "bigquery.googleapis.com", "cloudresourcemanager.googleapis.com", "cloudscheduler.googleapis.com",
      "compute.googleapis.com", "dlp.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com",
      "iap.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com",
      "networkmanagement.googleapis.com", "osconfig.googleapis.com", "pubsub.googleapis.com",
      "recommender.googleapis.com", "run.googleapis.com", "secretmanager.googleapis.com",
      "securitycenter.googleapis.com", "storage.googleapis.com",
    ]
    prod_data = [
      "bigquery.googleapis.com", "cloudkms.googleapis.com", "dlp.googleapis.com", "logging.googleapis.com",
      "monitoring.googleapis.com", "pubsub.googleapis.com", "storage.googleapis.com",
    ]
    observability = [
      "bigquery.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com",
      "pubsub.googleapis.com", "run.googleapis.com", "securitycenter.googleapis.com", "storage.googleapis.com",
    ]
    test = [
      "compute.googleapis.com", "iam.googleapis.com", "logging.googleapis.com",
      "monitoring.googleapis.com", "storage.googleapis.com",
    ]
    dev = [
      "compute.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com", "run.googleapis.com",
    ]
  }

  project_api_pairs = merge([
    for key, apis in local.project_apis : {
      for api in apis : "${key}|${api}" => { project = var.projects[key], api = api }
    }
  ]...)

  # Boolean constraints enforced at the organization root.
  boolean_policies = [
    "compute.disableSerialPortAccess",
    "compute.requireOsLogin",
    "compute.requireShieldedVm",
    "compute.skipDefaultNetworkCreation",
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "iam.disableServiceAccountKeyCreation",
    "iam.disableServiceAccountKeyUpload",
    "sql.restrictPublicIp",
    "storage.publicAccessPrevention",
    "storage.uniformBucketLevelAccess",
  ]

  data_class = {
    bootstrap     = "internal", network = "internal", dev = "internal", test = "internal",
    observability = "internal", prod_app = "phi", prod_data = "phi"
  }
  environment = {
    bootstrap = "platform", network = "platform", observability = "platform",
    dev       = "nonprod", test = "nonprod", prod_app = "prod", prod_data = "prod"
  }
}

resource "google_project_service" "apis" {
  for_each = local.project_api_pairs

  project            = each.value.project
  service            = each.value.api
  disable_on_destroy = false
}

# --- Organization policies -----------------------------------------------------
resource "google_org_policy_policy" "boolean" {
  for_each = toset(local.boolean_policies)

  name   = "${local.org_parent}/policies/${each.value}"
  parent = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "vm_external_ip" {
  name   = "${local.org_parent}/policies/compute.vmExternalIpAccess"
  parent = local.org_parent

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "${local.org_parent}/policies/gcp.resourceLocations"
  parent = local.org_parent

  spec {
    rules {
      values {
        allowed_values = ["in:us-locations"]
      }
    }
  }
}

resource "google_org_policy_policy" "run_ingress" {
  name   = "${local.org_parent}/policies/run.allowedIngress"
  parent = local.org_parent

  spec {
    rules {
      values {
        allowed_values = ["internal", "internal-and-cloud-load-balancing"]
      }
    }
  }
}

# Sandbox exception: the only folder where VMs may have external IPs.
resource "google_org_policy_policy" "sandbox_external_ip" {
  name   = "${var.folders.sandbox}/policies/compute.vmExternalIpAccess"
  parent = var.folders.sandbox

  spec {
    rules {
      allow_all = "TRUE"
    }
  }
}

# Custom constraint: every VM created in prod must have Secure Boot on.
resource "google_org_policy_custom_constraint" "secure_boot" {
  name           = "custom.mc360RequireSecureBoot"
  parent         = local.org_parent
  display_name   = "MedCloud360: VMs must enable Secure Boot"
  description    = "Shielded VM Secure Boot is mandatory for workloads that may process PHI."
  action_type    = "ALLOW"
  condition      = "resource.shieldedInstanceConfig.enableSecureBoot == true"
  method_types   = ["CREATE", "UPDATE"]
  resource_types = ["compute.googleapis.com/Instance"]
}

resource "google_org_policy_policy" "secure_boot_prod" {
  name   = "${var.folders.prod}/policies/${google_org_policy_custom_constraint.secure_boot.name}"
  parent = var.folders.prod

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# --- Resource tags -------------------------------------------------------------
resource "google_tags_tag_key" "data_class" {
  parent      = local.org_parent
  short_name  = "mc360-data-class"
  description = "Highest data classification a project may hold."
}

resource "google_tags_tag_value" "data_class" {
  for_each = toset(["phi", "internal"])

  parent     = google_tags_tag_key.data_class.id
  short_name = each.value
}

resource "google_tags_tag_key" "environment" {
  parent      = local.org_parent
  short_name  = "mc360-environment"
  description = "Environment of the project."
}

resource "google_tags_tag_value" "environment" {
  for_each = toset(["prod", "nonprod", "platform"])

  parent     = google_tags_tag_key.environment.id
  short_name = each.value
}

resource "google_tags_tag_binding" "data_class" {
  for_each = var.projects

  parent    = "//cloudresourcemanager.googleapis.com/projects/${data.google_project.p[each.key].number}"
  tag_value = google_tags_tag_value.data_class[local.data_class[each.key]].id
}

resource "google_tags_tag_binding" "environment" {
  for_each = var.projects

  parent    = "//cloudresourcemanager.googleapis.com/projects/${data.google_project.p[each.key].number}"
  tag_value = google_tags_tag_value.environment[local.environment[each.key]].id
}

# --- Organization firewall baseline (evaluated before every VPC rule) -----------
resource "google_compute_firewall_policy" "org_baseline" {
  parent      = local.org_parent
  short_name  = "mc360-org-baseline"
  description = "SSH/RDP only through IAP; everything else is decided by each VPC policy."
}

resource "google_compute_firewall_policy_rule" "iap_admin" {
  firewall_policy = google_compute_firewall_policy.org_baseline.name
  priority        = 1000
  direction       = "INGRESS"
  action          = "goto_next"
  description     = "IAP TCP forwarding for SSH/RDP is evaluated by the VPC policy."

  match {
    src_ip_ranges = ["35.235.240.0/20"]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22", "3389"]
    }
  }
}

resource "google_compute_firewall_policy_rule" "deny_admin_ports" {
  firewall_policy = google_compute_firewall_policy.org_baseline.name
  priority        = 2000
  direction       = "INGRESS"
  action          = "deny"
  enable_logging  = true
  description     = "No SSH/RDP from anywhere else, regardless of VPC rules."

  match {
    src_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22", "3389"]
    }
  }
}

resource "google_compute_firewall_policy_association" "org" {
  firewall_policy   = google_compute_firewall_policy.org_baseline.id
  attachment_target = local.org_parent
  name              = "mc360-org-baseline"
}

# --- Central audit logging -----------------------------------------------------
resource "google_storage_bucket" "audit_archive" {
  name                        = "mc360-org-audit-${data.google_project.p["observability"].number}"
  project                     = var.projects.observability
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  # 7 years. Left unlocked on purpose: locking is permanent (lock after sign-off in a real org).
  retention_policy {
    retention_period = 220752000
    is_locked        = false
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
  }

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_dataset" "siem" {
  project                         = var.projects.observability
  dataset_id                      = "org_audit_siem"
  friendly_name                   = "MedCloud360 security data lake"
  location                        = var.region
  delete_contents_on_destroy      = false
  default_partition_expiration_ms = 220752000000

  depends_on = [google_project_service.apis]
}

resource "google_logging_project_bucket_config" "security" {
  project          = var.projects.observability
  location         = var.region
  bucket_id        = "mc360-security-logs"
  retention_days   = 30
  enable_analytics = true
  description      = "Org-wide audit logs for log-based security alerts."

  depends_on = [google_project_service.apis]
}

locals {
  audit_filter = "logName:\"cloudaudit.googleapis.com\""
}

resource "google_logging_organization_sink" "to_gcs" {
  name             = "mc360-audit-to-gcs"
  org_id           = var.org_id
  include_children = true
  filter           = local.audit_filter
  destination      = "storage.googleapis.com/${google_storage_bucket.audit_archive.name}"
}

resource "google_logging_organization_sink" "to_bigquery" {
  name             = "mc360-audit-to-bigquery"
  org_id           = var.org_id
  include_children = true
  filter           = local.audit_filter
  destination      = "bigquery.googleapis.com/projects/${var.projects.observability}/datasets/${google_bigquery_dataset.siem.dataset_id}"

  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_logging_organization_sink" "to_log_bucket" {
  name             = "mc360-audit-to-log-bucket"
  org_id           = var.org_id
  include_children = true
  filter           = local.audit_filter
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.security.id}"
}

resource "google_storage_bucket_iam_member" "sink_gcs" {
  bucket = google_storage_bucket.audit_archive.name
  role   = "roles/storage.objectCreator"
  member = google_logging_organization_sink.to_gcs.writer_identity
}

resource "google_bigquery_dataset_iam_member" "sink_bq" {
  project    = var.projects.observability
  dataset_id = google_bigquery_dataset.siem.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_organization_sink.to_bigquery.writer_identity
}

resource "google_project_iam_member" "sink_log_bucket" {
  project = var.projects.observability
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.to_log_bucket.writer_identity
}

# Data Access audit logs (who READ PHI) — off by default in GCP, on for the PHI project.
resource "google_project_iam_audit_config" "phi_data_access" {
  for_each = toset(["storage.googleapis.com", "bigquery.googleapis.com"])

  project = var.projects.prod_data
  service = each.value

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# --- Budgets ---------------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  project      = var.projects.observability
  display_name = "MedCloud360 platform alerts"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.apis]
}

resource "google_billing_budget" "project" {
  for_each = var.projects

  billing_account = var.billing_account
  display_name    = "mc360-${each.key}"

  budget_filter {
    projects = ["projects/${data.google_project.p[each.key].number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = false
  }
}
