# =============================================================================
# Stage 06 — CareNotes serverless application (mc360-prj-prod-app)
#  * Artifact Registry (images built and deployed by GitHub Actions)
#  * Cloud Run: portal (2 regions, LB-only ingress), processor (internal ingress)
#  * Cloud Run jobs: hl7-sim (MLLP/TLS sender), daily-report (Cloud Scheduler)
#  * GCS upload -> Pub/Sub -> authenticated push -> processor (DLP + Gemini -> BigQuery)
#  * scc-router (observability): SCC findings -> structured alert + auto-remediation
#  * Control self-test targets (outside bucket, key-less service account)
#  * Optional Binary Authorization: only images from this registry may run
# =============================================================================

locals {
  project = var.projects.prod_app
  num     = data.terraform_remote_state.org.outputs.project_numbers
  net     = data.terraform_remote_state.network.outputs
  sec     = data.terraform_remote_state.security.outputs
  dat     = data.terraform_remote_state.data.outputs
  sa      = local.sec.service_accounts

  regions       = var.enable_dr_region ? [var.region, var.dr_region] : [var.region]
  region_subnet = { (var.region) = "prod-app-usc1", (var.dr_region) = "prod-app-use4" }
  prod_network  = "projects/${var.projects.network}/global/networks/${local.net.networks["prod"].name}"
  placeholder   = "us-docker.pkg.dev/cloudrun/container/hello"
  image         = "${var.region}-docker.pkg.dev/${local.project}/carenotes/carenotes:latest"

  env = {
    ORG_ID                  = var.org_id
    PROJECT_APP             = local.project
    PROJECT_DATA            = var.projects.prod_data
    PROJECT_OBS             = var.projects.observability
    PROJECT_TEST            = var.projects.test
    PROJECT_NETWORK         = var.projects.network
    REGION                  = var.region
    INTAKE_BUCKET           = local.dat.buckets["phi-intake"]
    CLAIMS_BUCKET           = local.dat.buckets["claims-export"]
    DATASET                 = local.dat.dataset
    BQ_KMS_KEY              = local.sec.kms_keys["bigquery"]
    DLP_INSPECT_TEMPLATE    = local.dat.dlp_templates["inspect"]
    DLP_DEID_TEMPLATE       = local.dat.dlp_templates["deidentify"]
    GEMINI_MODEL            = "gemini-2.5-flash"
    HL7_HOST                = data.terraform_remote_state.compute.outputs.hl7_ip
    HL7_PORT                = "2575"
    HL7_JOB                 = "hl7-sim"
    SIEM_DATASET            = "org_audit_siem"
    SCC_DATASET             = "scc_findings"
    SELFTEST_TARGET_SA      = local.sa["selftest-target"]
    SELFTEST_OUTSIDE_BUCKET = google_storage_bucket.outside.name
  }
}

# --- Artifact Registry -----------------------------------------------------------------
resource "google_artifact_registry_repository" "carenotes" {
  project       = local.project
  location      = var.region
  repository_id = "carenotes"
  format        = "DOCKER"
  description   = "CareNotes images (pushed by GitHub Actions, referenced by digest)"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "obs_pull" {
  project    = local.project
  location   = var.region
  repository = google_artifact_registry_repository.carenotes.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:service-${local.num["observability"]}@serverless-robot-prod.iam.gserviceaccount.com"
}

# --- Binary Authorization (optional) -----------------------------------------------------
resource "google_binary_authorization_policy" "policy" {
  count   = var.enable_binary_authorization ? 1 : 0
  project = local.project

  global_policy_evaluation_mode = "ENABLE"

  admission_whitelist_patterns {
    name_pattern = "${var.region}-docker.pkg.dev/${local.project}/carenotes/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_DENY"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }
}

# --- Cloud Run: portal (2 regions, only reachable through the load balancer + IAP) --------
resource "google_cloud_run_v2_service" "portal" {
  for_each = toset(local.regions)

  project             = local.project
  name                = "carenotes-portal"
  location            = each.value
  ingress             = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  deletion_protection = false

  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      use_default = true
    }
  }

  template {
    service_account                  = local.sa["portal"]
    max_instance_request_concurrency = 40
    timeout                          = "60s"

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = local.prod_network
        subnetwork = "projects/${var.projects.network}/regions/${each.value}/subnetworks/${local.region_subnet[each.value]}"
      }
    }

    containers {
      image = local.placeholder
      args  = ["portal"]

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }

      dynamic "env" {
        for_each = merge(local.env, { SERVING_REGION = each.value })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, template[0].containers[0].args, client, client_version]
  }
}

# --- Cloud Run: processor (internal ingress, invoked by authenticated Pub/Sub push) --------
resource "google_cloud_run_v2_service" "processor" {
  project             = local.project
  name                = "carenotes-processor"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      use_default = true
    }
  }

  template {
    service_account                  = local.sa["processor"]
    max_instance_request_concurrency = 4
    timeout                          = "300s"

    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }

    containers {
      image = local.placeholder
      args  = ["processor"]

      resources {
        limits = { cpu = "1", memory = "1Gi" }
      }

      dynamic "env" {
        for_each = local.env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, template[0].containers[0].args, client, client_version]
  }
}

# --- Cloud Run jobs ------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "job" {
  for_each = {
    hl7-sim      = { args = ["job-hl7-sim"], vpc = true, timeout = "600s" }
    daily-report = { args = ["job-daily-report"], vpc = false, timeout = "600s" }
  }

  project             = local.project
  name                = each.key
  location            = var.region
  deletion_protection = false

  template {
    task_count = 1

    template {
      service_account = local.sa["jobs"]
      timeout         = each.value.timeout
      max_retries     = 0

      dynamic "vpc_access" {
        for_each = each.value.vpc ? [1] : []
        content {
          egress = "PRIVATE_RANGES_ONLY"
          network_interfaces {
            network    = local.prod_network
            subnetwork = "projects/${var.projects.network}/regions/${var.region}/subnetworks/prod-app-usc1"
          }
        }
      }

      containers {
        image = local.placeholder
        args  = each.value.args

        resources {
          limits = { cpu = "1", memory = "512Mi" }
        }

        dynamic "env" {
          for_each = local.env
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image, template[0].template[0].containers[0].args, client, client_version]
  }
}

# --- Upload pipeline: GCS notification topic -> push subscription -> processor -----------------
resource "google_project_service_identity" "pubsub_app" {
  provider = google-beta
  project  = local.project
  service  = "pubsub.googleapis.com"
}

resource "google_service_account_iam_member" "pubsub_token" {
  service_account_id = "projects/${local.project}/serviceAccounts/${local.sa["invoker"]}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_project_service_identity.pubsub_app.member
}

resource "google_cloud_run_v2_service_iam_member" "processor_invoker" {
  project  = local.project
  location = var.region
  name     = google_cloud_run_v2_service.processor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.sa["invoker"]}"
}

resource "google_pubsub_subscription" "note_uploaded" {
  project = local.project
  name    = "note-uploaded-to-processor"
  topic   = local.dat.topics["note-uploaded"]

  ack_deadline_seconds = 300

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.processor.uri}/pubsub/note"
    oidc_token {
      service_account_email = local.sa["invoker"]
      audience              = google_cloud_run_v2_service.processor.uri
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  depends_on = [google_service_account_iam_member.pubsub_token]
}

resource "google_pubsub_topic" "dead_letter" {
  project = local.project
  name    = "carenotes-dead-letter"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = local.project
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = google_project_service_identity.pubsub_app.member
}

resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  project      = local.project
  subscription = google_pubsub_subscription.note_uploaded.name
  role         = "roles/pubsub.subscriber"
  member       = google_project_service_identity.pubsub_app.member
}

# --- Scheduler -> daily-report job ----------------------------------------------------------
resource "google_cloud_run_v2_job_iam_member" "jobs_invoker" {
  for_each = {
    "daily-report|invoker" = { job = "daily-report", member = "serviceAccount:${local.sa["invoker"]}" }
    "hl7-sim|portal"       = { job = "hl7-sim", member = "serviceAccount:${local.sa["portal"]}" }
    "daily-report|portal"  = { job = "daily-report", member = "serviceAccount:${local.sa["portal"]}" }
  }

  project  = local.project
  location = var.region
  name     = google_cloud_run_v2_job.job[each.value.job].name
  role     = "roles/run.invoker"
  member   = each.value.member
}

resource "google_cloud_scheduler_job" "daily_report" {
  project     = local.project
  region      = var.region
  name        = "carenotes-daily-report"
  description = "06:00 Phoenix — aggregate yesterday's notes and HL7 volume, export de-identified CSV"
  schedule    = "0 6 * * *"
  time_zone   = "America/Phoenix"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${local.project}/locations/${var.region}/jobs/daily-report:run"

    oauth_token {
      service_account_email = local.sa["invoker"]
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}

# --- Runtime permissions (least privilege) ----------------------------------------------------
resource "google_project_iam_member" "app" {
  for_each = {
    "processor|aiplatform" = { sa = "processor", role = "roles/aiplatform.user", project = local.project }
    "portal|osconfig-vuln" = { sa = "portal", role = "roles/osconfig.vulnerabilityReportViewer", project = local.project }
    "portal|osconfig-inv"  = { sa = "portal", role = "roles/osconfig.inventoryViewer", project = local.project }
    "portal|patchjobs"     = { sa = "portal", role = "roles/osconfig.patchJobViewer", project = local.project }
    "portal|compute"       = { sa = "portal", role = "roles/compute.viewer", project = local.project }
    "portal|run-viewer"    = { sa = "portal", role = "roles/run.viewer", project = local.project }
    "portal|recommender"   = { sa = "portal", role = "roles/recommender.iamViewer", project = local.project }
    "portal|monitoring"    = { sa = "portal", role = "roles/monitoring.viewer", project = var.projects.observability }
    "portal|netmgmt"       = { sa = "portal", role = "roles/networkmanagement.viewer", project = var.projects.network }
    "portal|bq-obs-jobs"   = { sa = "portal", role = "roles/bigquery.jobUser", project = var.projects.observability }
  }

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${local.sa[each.value.sa]}"
}

resource "google_organization_iam_member" "portal_scc" {
  org_id = var.org_id
  role   = "roles/securitycenter.findingsViewer"
  member = "serviceAccount:${local.sa["portal"]}"
}

resource "google_bigquery_dataset_iam_member" "portal_obs" {
  for_each = toset(["org_audit_siem", "scc_findings"])

  project    = var.projects.observability
  dataset_id = each.value
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${local.sa["portal"]}"
}

# --- Control self-test targets ---------------------------------------------------------------
# A bucket OUTSIDE the perimeter (mc360-prj-test). The portal may write to it per IAM, so only
# VPC Service Controls can stop the exfiltration attempt — that is what the test proves.
resource "google_storage_bucket" "outside" {
  name                        = "mc360-selftest-outside-${local.num["test"]}"
  project                     = var.projects.test
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

resource "google_storage_bucket_iam_member" "outside_portal" {
  bucket = google_storage_bucket.outside.name
  role   = "roles/storage.admin" # lets the test also TRY to make it public (org policy must refuse)
  member = "serviceAccount:${local.sa["portal"]}"
}

resource "google_service_account_iam_member" "selftest_key_attempt" {
  service_account_id = "projects/${var.projects.test}/serviceAccounts/${local.sa["selftest-target"]}"
  role               = "roles/iam.serviceAccountKeyAdmin" # IAM allows it; the org policy must refuse it
  member             = "serviceAccount:${local.sa["portal"]}"
}

# Allows the self-test to try creating a non-CMEK bucket in the prod folder (CMEK policy must refuse).
resource "google_project_iam_member" "selftest_bucket_attempt" {
  project = var.projects.prod_data
  role    = "roles/storage.admin"
  member  = "serviceAccount:${local.sa["portal"]}"

  condition {
    title       = "selftest-buckets-only"
    description = "Only buckets named mc360-selftest-*"
    expression  = "resource.name.startsWith(\"projects/_/buckets/mc360-selftest-\")"
  }
}

# --- scc-router (observability project) -------------------------------------------------------
resource "google_cloud_run_v2_service" "scc_router" {
  project             = var.projects.observability
  name                = "scc-router"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = local.sa["scc-router"]

    scaling {
      max_instance_count = 2
    }

    containers {
      image = local.placeholder
      args  = ["scc-router"]

      dynamic "env" {
        for_each = { PROJECT_TEST = var.projects.test, REMEDIATE_PROJECTS = var.projects.test }
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, template[0].containers[0].args, client, client_version]
  }

  depends_on = [google_artifact_registry_repository_iam_member.obs_pull]
}

resource "google_project_service_identity" "pubsub_obs" {
  provider = google-beta
  project  = var.projects.observability
  service  = "pubsub.googleapis.com"
}

resource "google_service_account_iam_member" "obs_pubsub_token" {
  service_account_id = "projects/${local.project}/serviceAccounts/${local.sa["invoker"]}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_project_service_identity.pubsub_obs.member
}

resource "google_cloud_run_v2_service_iam_member" "scc_router_invoker" {
  project  = var.projects.observability
  location = var.region
  name     = google_cloud_run_v2_service.scc_router.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.sa["invoker"]}"
}

resource "google_pubsub_subscription" "scc_router" {
  project = var.projects.observability
  name    = "scc-findings-to-router"
  topic   = local.sec.scc_topic

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.scc_router.uri}/scc"
    oidc_token {
      service_account_email = local.sa["invoker"]
      audience              = google_cloud_run_v2_service.scc_router.uri
    }
  }

  depends_on = [google_service_account_iam_member.obs_pubsub_token]
}

# Auto-remediation scope: the lab project only (where misconfigurations are seeded on purpose).
resource "google_project_iam_member" "scc_router_remediate" {
  project = var.projects.test
  role    = "roles/storage.admin"
  member  = "serviceAccount:${local.sa["scc-router"]}"
}
