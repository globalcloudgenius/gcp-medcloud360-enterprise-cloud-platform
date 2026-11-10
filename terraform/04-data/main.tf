# =============================================================================
# Stage 04 — PHI data layer (mc360-prj-prod-data)
#  * CMEK buckets: phi-intake (uploaded notes), claims-export
#  * BigQuery dataset carenotes (CMEK): visits, hl7_messages, daily_reports
#  * Pub/Sub: note-uploaded (GCS notifications), hl7-adt (from the HL7 gateway)
#  * HL7 messages land in BigQuery through a BigQuery subscription (no code)
#  * Sensitive Data Protection inspect + de-identify templates
#  * Least-privilege grants for each workload identity
# =============================================================================

data "google_project" "data" {
  project_id = var.projects.prod_data
}

data "google_storage_project_service_account" "data" {
  project = var.projects.prod_data
}

locals {
  project      = var.projects.prod_data
  keys         = data.terraform_remote_state.security.outputs.kms_keys
  sa           = data.terraform_remote_state.security.outputs.service_accounts
  suffix       = data.google_project.data.number
  pubsub_agent = "serviceAccount:service-${data.google_project.data.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# --- Buckets -----------------------------------------------------------------------------
resource "google_storage_bucket" "b" {
  for_each = {
    phi-intake    = "Uploaded synthetic visit notes (raw PHI)"
    claims-export = "De-identified daily claims extracts"
  }

  name                        = "mc360-${each.key}-${local.suffix}"
  project                     = local.project
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # synthetic lab data only

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = local.keys["storage"]
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    data-class = each.key == "phi-intake" ? "phi" : "deidentified"
  }
}

# --- Pub/Sub -------------------------------------------------------------------------------
resource "google_pubsub_topic" "t" {
  for_each = toset(["note-uploaded", "hl7-adt"])

  project      = local.project
  name         = each.value
  kms_key_name = local.keys["pubsub"]

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_topic_iam_member" "gcs_publisher" {
  project = local.project
  topic   = google_pubsub_topic.t["note-uploaded"].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.data.email_address}"
}

resource "google_storage_notification" "intake" {
  bucket         = google_storage_bucket.b["phi-intake"].name
  topic          = google_pubsub_topic.t["note-uploaded"].id
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE"]

  depends_on = [google_pubsub_topic_iam_member.gcs_publisher]
}

resource "google_pubsub_topic_iam_member" "hl7_publisher" {
  project = local.project
  topic   = google_pubsub_topic.t["hl7-adt"].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.sa["hl7-gw"]}"
}

# --- BigQuery -------------------------------------------------------------------------------
resource "google_bigquery_dataset" "carenotes" {
  project                    = local.project
  dataset_id                 = "carenotes"
  friendly_name              = "CareNotes clinical analytics (de-identified + HL7 feed)"
  location                   = var.region
  delete_contents_on_destroy = true

  default_encryption_configuration {
    kms_key_name = local.keys["bigquery"]
  }
}

resource "google_bigquery_table" "visits" {
  project             = local.project
  dataset_id          = google_bigquery_dataset.carenotes.dataset_id
  table_id            = "visits"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "processed_at"
  }

  schema = jsonencode([
    { name = "note_id", type = "STRING", mode = "REQUIRED" },
    { name = "object_name", type = "STRING" },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "phi_findings", type = "JSON", description = "infoType -> count found by DLP" },
    { name = "deidentified_text", type = "STRING" },
    { name = "summary", type = "STRING", description = "Gemini summary of the de-identified note" },
    { name = "processing_ms", type = "INTEGER" },
    { name = "region", type = "STRING" },
  ])
}

resource "google_bigquery_table" "hl7_messages" {
  project             = local.project
  dataset_id          = google_bigquery_dataset.carenotes.dataset_id
  table_id            = "hl7_messages"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "publish_time"
  }

  # Layout required by a Pub/Sub BigQuery subscription with write_metadata = true.
  schema = jsonencode([
    { name = "subscription_name", type = "STRING" },
    { name = "message_id", type = "STRING" },
    { name = "publish_time", type = "TIMESTAMP" },
    { name = "data", type = "STRING" },
    { name = "attributes", type = "STRING" },
  ])
}

resource "google_bigquery_table" "daily_reports" {
  project             = local.project
  dataset_id          = google_bigquery_dataset.carenotes.dataset_id
  table_id            = "daily_reports"
  deletion_protection = false

  schema = jsonencode([
    { name = "report_date", type = "DATE", mode = "REQUIRED" },
    { name = "notes_processed", type = "INTEGER" },
    { name = "hl7_messages", type = "INTEGER" },
    { name = "phi_by_type", type = "JSON" },
    { name = "generated_at", type = "TIMESTAMP" },
  ])
}

resource "google_bigquery_dataset_iam_member" "pubsub_writer" {
  project    = local.project
  dataset_id = google_bigquery_dataset.carenotes.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.pubsub_agent
}

resource "google_pubsub_subscription" "hl7_to_bq" {
  project = local.project
  name    = "hl7-adt-to-bigquery"
  topic   = google_pubsub_topic.t["hl7-adt"].id

  bigquery_config {
    table          = "${local.project}.${google_bigquery_dataset.carenotes.dataset_id}.${google_bigquery_table.hl7_messages.table_id}"
    write_metadata = true
  }

  message_retention_duration = "604800s"

  depends_on = [google_bigquery_dataset_iam_member.pubsub_writer]
}

# --- Sensitive Data Protection --------------------------------------------------------------
locals {
  dlp_parent = "projects/${local.project}/locations/${var.region}"
  info_types = [
    "PERSON_NAME", "US_SOCIAL_SECURITY_NUMBER", "DATE_OF_BIRTH", "PHONE_NUMBER",
    "EMAIL_ADDRESS", "STREET_ADDRESS", "US_HEALTHCARE_NPI", "MEDICAL_RECORD_NUMBER",
  ]
}

resource "google_data_loss_prevention_inspect_template" "phi" {
  parent       = local.dlp_parent
  template_id  = "carenotes-phi"
  display_name = "CareNotes PHI inspection"
  description  = "PHI/PII infoTypes found in clinical visit notes"

  inspect_config {
    min_likelihood = "POSSIBLE"
    include_quote  = false

    dynamic "info_types" {
      for_each = local.info_types
      content {
        name = info_types.value
      }
    }
  }
}

resource "google_data_loss_prevention_deidentify_template" "phi" {
  parent       = local.dlp_parent
  template_id  = "carenotes-deidentify"
  display_name = "CareNotes PHI de-identification"
  description  = "Replace each PHI value with its infoType name"

  deidentify_config {
    info_type_transformations {
      transformations {
        primitive_transformation {
          replace_with_info_type_config = true
        }
      }
    }
  }
}

# --- Least-privilege grants per workload ---------------------------------------------------
locals {
  sa_member = { for k, v in local.sa : k => "serviceAccount:${v}" }

  project_roles = {
    "processor|roles/bigquery.jobUser" = { sa = "processor", role = "roles/bigquery.jobUser" }
    "processor|roles/dlp.user"         = { sa = "processor", role = "roles/dlp.user" }
    "processor|inspect"                = { sa = "processor", role = "roles/dlp.inspectTemplatesReader" }
    "processor|deid"                   = { sa = "processor", role = "roles/dlp.deidentifyTemplatesReader" }
    "portal|roles/bigquery.jobUser"    = { sa = "portal", role = "roles/bigquery.jobUser" }
    "jobs|roles/bigquery.jobUser"      = { sa = "jobs", role = "roles/bigquery.jobUser" }
  }
}

resource "google_project_iam_member" "workloads" {
  for_each = local.project_roles

  project = local.project
  role    = each.value.role
  member  = local.sa_member[each.value.sa]
}

resource "google_storage_bucket_iam_member" "intake" {
  for_each = {
    portal    = "roles/storage.objectCreator"
    processor = "roles/storage.objectViewer"
  }

  bucket = google_storage_bucket.b["phi-intake"].name
  role   = each.value
  member = local.sa_member[each.key]
}

# Portal reads its own uploads back for the result page and the self-test.
resource "google_storage_bucket_iam_member" "intake_portal_read" {
  bucket = google_storage_bucket.b["phi-intake"].name
  role   = "roles/storage.objectViewer"
  member = local.sa_member["portal"]
}

resource "google_storage_bucket_iam_member" "claims" {
  bucket = google_storage_bucket.b["claims-export"].name
  role   = "roles/storage.objectCreator"
  member = local.sa_member["jobs"]
}

resource "google_bigquery_dataset_iam_member" "carenotes" {
  for_each = {
    processor = "roles/bigquery.dataEditor"
    jobs      = "roles/bigquery.dataEditor"
    portal    = "roles/bigquery.dataViewer"
  }

  project    = local.project
  dataset_id = google_bigquery_dataset.carenotes.dataset_id
  role       = each.value
  member     = local.sa_member[each.key]
}
