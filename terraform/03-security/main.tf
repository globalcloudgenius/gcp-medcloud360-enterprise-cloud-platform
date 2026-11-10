# =============================================================================
# Stage 03 — Security foundation
#  * Cloud KMS key ring (prod-data) with 90-day rotation; keys per service
#  * Service agents granted BEFORE CMEK is enforced (keys -> grants -> enforce)
#  * CMEK org policies on the prod folder (enforce_cmek = true to turn on)
#  * Workload service accounts (no keys — key creation is blocked org-wide)
#  * Secret Manager: HL7 TLS material (internal CA + server certificate)
#  * Security Command Center: findings -> Pub/Sub + BigQuery, mute rule
# =============================================================================

data "google_project" "p" {
  for_each   = var.projects
  project_id = each.value
}

locals {
  data_project = var.projects.prod_data
  app_project  = var.projects.prod_app
  num          = { for k, p in data.google_project.p : k => p.number }
}

# --- Cloud KMS -----------------------------------------------------------------------
resource "google_kms_key_ring" "prod" {
  project  = local.data_project
  name     = "mc360-prod-${var.region}"
  location = var.region
}

resource "google_kms_crypto_key" "key" {
  for_each = toset(["storage", "bigquery", "compute", "pubsub", "secrets"])

  name            = each.value
  key_ring        = google_kms_key_ring.prod.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 days

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE" # HSM costs per key version; documented upgrade path
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_storage_project_service_account" "data" {
  project = local.data_project
}

data "google_bigquery_default_service_account" "data" {
  project = local.data_project
}

resource "google_project_service_identity" "pubsub" {
  provider = google-beta
  project  = local.data_project
  service  = "pubsub.googleapis.com"
}

resource "google_project_service_identity" "secretmanager" {
  provider = google-beta
  project  = local.app_project
  service  = "secretmanager.googleapis.com"
}

locals {
  # One service agent per key; keys are static so for_each is known at plan time.
  key_users = {
    storage  = "serviceAccount:${data.google_storage_project_service_account.data.email_address}"
    bigquery = "serviceAccount:${data.google_bigquery_default_service_account.data.email}"
    compute  = "serviceAccount:service-${local.num["prod_app"]}@compute-system.iam.gserviceaccount.com"
    pubsub   = google_project_service_identity.pubsub.member
    secrets  = google_project_service_identity.secretmanager.member
  }
}

resource "google_kms_crypto_key_iam_member" "agents" {
  for_each = toset(keys(google_kms_crypto_key.key))

  crypto_key_id = google_kms_crypto_key.key[each.value].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = local.key_users[each.value]
}

# --- CMEK enforcement on the prod folder (observe -> enforce) ------------------------
resource "google_org_policy_policy" "restrict_non_cmek" {
  count = var.enforce_cmek ? 1 : 0

  name   = "${var.folders.prod}/policies/gcp.restrictNonCmekServices"
  parent = var.folders.prod

  spec {
    rules {
      values {
        denied_values = ["storage.googleapis.com", "bigquery.googleapis.com"]
      }
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

resource "google_org_policy_policy" "restrict_cmek_projects" {
  count = var.enforce_cmek ? 1 : 0

  name   = "${var.folders.prod}/policies/gcp.restrictCmekCryptoKeyProjects"
  parent = var.folders.prod

  spec {
    rules {
      values {
        allowed_values = ["under:projects/${local.data_project}"]
      }
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# --- Workload identities (no keys anywhere) ---------------------------------------------
locals {
  app_service_accounts = {
    portal    = "CareNotes portal (Cloud Run, behind IAP)"
    processor = "CareNotes note processor (DLP + Gemini)"
    jobs      = "CareNotes batch jobs (HL7 simulator, daily report)"
    hl7-gw    = "HL7 MLLP gateway VMs"
    invoker   = "Pub/Sub push and Cloud Scheduler invoker"
  }
}

resource "google_service_account" "app" {
  for_each = local.app_service_accounts

  project      = local.app_project
  account_id   = "carenotes-${each.key}"
  display_name = each.value
}

resource "google_service_account" "scc_router" {
  project      = var.projects.observability
  account_id   = "scc-router"
  display_name = "SCC finding router and auto-remediation"
}

# A deliberately unused identity: the portal's control self-test tries to create a key
# for it, and the organization policy must refuse.
resource "google_service_account" "selftest_target" {
  project      = var.projects.test
  account_id   = "selftest-target"
  display_name = "Control self-test target (never used by workloads)"
}

# --- Secret Manager: HL7 TLS (MLLP over TLS — PHI is never sent in clear text) ---------
resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 8760

  subject {
    common_name  = "MedCloud360 Internal CA"
    organization = "MedCloud360"
  }

  allowed_uses = ["cert_signing", "crl_signing", "digital_signature"]
}

resource "tls_private_key" "hl7" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "hl7" {
  private_key_pem = tls_private_key.hl7.private_key_pem
  dns_names       = ["hl7.mc360.internal"]
  ip_addresses    = ["10.42.0.10"]

  subject {
    common_name  = "hl7.mc360.internal"
    organization = "MedCloud360"
  }
}

resource "tls_locally_signed_cert" "hl7" {
  cert_request_pem      = tls_cert_request.hl7.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 4380
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

locals {
  secrets = {
    hl7-tls-cert = tls_locally_signed_cert.hl7.cert_pem
    hl7-tls-key  = tls_private_key.hl7.private_key_pem
    hl7-ca-cert  = tls_self_signed_cert.ca.cert_pem
  }
}

resource "google_secret_manager_secret" "s" {
  for_each = local.secrets

  project   = local.app_project
  secret_id = each.key

  replication {
    user_managed {
      replicas {
        location = var.region
        customer_managed_encryption {
          kms_key_name = google_kms_crypto_key.key["secrets"].id
        }
      }
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

resource "google_secret_manager_secret_version" "s" {
  for_each = local.secrets

  secret      = google_secret_manager_secret.s[each.key].id
  secret_data = each.value
}

resource "google_secret_manager_secret_iam_member" "hl7_gw" {
  for_each = toset(["hl7-tls-cert", "hl7-tls-key"])

  project   = local.app_project
  secret_id = google_secret_manager_secret.s[each.value].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.app["hl7-gw"].member
}

resource "google_secret_manager_secret_iam_member" "ca_readers" {
  for_each = toset(["jobs", "portal"])

  project   = local.app_project
  secret_id = google_secret_manager_secret.s["hl7-ca-cert"].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.app[each.value].member
}

# --- Security Command Center (Standard tier, already active) ----------------------------
resource "google_pubsub_topic" "scc_findings" {
  project = var.projects.observability
  name    = "scc-findings"
}

resource "google_scc_v2_organization_notification_config" "high" {
  config_id    = "mc360-high-critical"
  organization = var.org_id
  location     = "global"
  description  = "Active HIGH and CRITICAL findings -> scc-router (alert, ticket, auto-remediation)"
  pubsub_topic = google_pubsub_topic.scc_findings.id

  streaming_config {
    filter = "state = \"ACTIVE\" AND (severity = \"HIGH\" OR severity = \"CRITICAL\") AND mute != \"MUTED\""
  }
}

resource "google_pubsub_topic_iam_member" "scc_publisher" {
  project = var.projects.observability
  topic   = google_pubsub_topic.scc_findings.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-org-${var.org_id}@gcp-sa-scc-notification.iam.gserviceaccount.com"
}

resource "google_bigquery_dataset" "scc" {
  project                    = var.projects.observability
  dataset_id                 = "scc_findings"
  friendly_name              = "Security Command Center findings"
  location                   = var.region
  delete_contents_on_destroy = false
}

resource "google_bigquery_dataset_iam_member" "scc_export" {
  project    = var.projects.observability
  dataset_id = google_bigquery_dataset.scc.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-org-${var.org_id}@security-center-api.iam.gserviceaccount.com"
}

resource "google_scc_v2_organization_scc_big_query_export" "all" {
  big_query_export_id = "mc360-findings"
  organization        = var.org_id
  location            = "global"
  dataset             = google_bigquery_dataset.scc.id
  description         = "All findings to the security data lake"
  filter              = ""

  depends_on = [google_bigquery_dataset_iam_member.scc_export]
}

# Documented exception: the sandbox lab intentionally holds misconfigured resources.
resource "google_scc_v2_organization_mute_config" "sandbox_lab" {
  mute_config_id = "mc360-sandbox-lab"
  organization   = var.org_id
  location       = "global"
  type           = "STATIC"
  description    = "Accepted risk (owner: platform team, review every 90 days): fld-mc360-sandbox lab findings"
  filter         = "resource.folders.resource_folder_display_name = \"fld-mc360-sandbox\""
}
