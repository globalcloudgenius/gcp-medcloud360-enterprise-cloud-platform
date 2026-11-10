# =============================================================================
# Stage 00 — Bootstrap (run once from Cloud Shell / laptop, then CI takes over)
#  * APIs on the bootstrap project (every org-level call is billed here)
#  * Terraform state bucket (only when it does not exist yet)
#  * Workload Identity Federation for GitHub Actions — no service account keys
#  * CI identities: plan (read-only), apply (deploy), app (build + deploy images)
# =============================================================================

data "google_project" "bootstrap" {
  project_id = var.projects.bootstrap
}

locals {
  bootstrap_apis = [
    "aiplatform.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloudasset.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "dlp.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "networkconnectivity.googleapis.com",
    "networkmanagement.googleapis.com",
    "orgpolicy.googleapis.com",
    "osconfig.googleapis.com",
    "pubsub.googleapis.com",
    "recommender.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "securitycenter.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]

  all_project_ids = values(var.projects)

  # Deployer role set granted on every MedCloud360 project to the apply identity.
  # Tier-2 hardening (documented): split into one identity per stage.
  apply_project_roles = [
    "roles/artifactregistry.admin",
    "roles/bigquery.admin",
    "roles/binaryauthorization.policyEditor",
    "roles/cloudkms.admin",
    "roles/cloudscheduler.admin",
    "roles/compute.admin",
    "roles/dlp.admin",
    "roles/dns.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iap.admin",
    "roles/logging.admin",
    "roles/monitoring.admin",
    "roles/networkconnectivity.hubAdmin",
    "roles/networkmanagement.admin",
    "roles/osconfig.osPolicyAssignmentAdmin",
    "roles/osconfig.patchDeploymentAdmin",
    "roles/pubsub.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
  ]

  apply_org_roles = [
    "roles/accesscontextmanager.policyAdmin",
    "roles/browser",
    "roles/compute.orgFirewallPolicyAdmin",
    "roles/compute.orgSecurityResourceAdmin",
    "roles/compute.xpnAdmin",
    "roles/iam.organizationRoleViewer",
    "roles/logging.configWriter",
    "roles/orgpolicy.policyAdmin",
    "roles/resourcemanager.tagAdmin",
    "roles/resourcemanager.tagUser",
    "roles/securitycenter.bigQueryExportsEditor",
    "roles/securitycenter.findingsViewer",
    "roles/securitycenter.muteConfigsEditor",
    "roles/securitycenter.notificationConfigEditor",
  ]

  plan_org_roles = [
    "roles/accesscontextmanager.policyReader",
    "roles/iam.securityReviewer",
    "roles/orgpolicy.policyViewer",
    "roles/securitycenter.adminViewer",
    "roles/viewer",
  ]

  wif_pool = "projects/${data.google_project.bootstrap.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}"

  # GitHub OIDC subject for jobs that run in the protected "production" environment.
  prod_env_subject = "repo:${var.github_repository}:environment:production"
}

resource "google_project_service" "bootstrap" {
  for_each = toset(local.bootstrap_apis)

  project            = var.projects.bootstrap
  service            = each.value
  disable_on_destroy = false
}

# --- Terraform state bucket ---------------------------------------------------
resource "google_storage_bucket" "state" {
  count = var.create_state_bucket ? 1 : 0

  name                        = var.state_bucket
  project                     = var.projects.bootstrap
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bootstrap]
}

# --- Workload Identity Federation for GitHub Actions ---------------------------
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.projects.bootstrap
  workload_identity_pool_id = "mc360-github"
  display_name              = "MedCloud360 GitHub Actions"
  description               = "Keyless CI/CD for ${var.github_repository}"

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.projects.bootstrap
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Only this repository can exchange tokens at all.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- CI identities -------------------------------------------------------------
resource "google_service_account" "plan" {
  project      = var.projects.bootstrap
  account_id   = "mc360-tf-plan"
  display_name = "Terraform plan (read-only, any branch / PR)"
}

resource "google_service_account" "apply" {
  project      = var.projects.bootstrap
  account_id   = "mc360-tf-apply"
  display_name = "Terraform apply (production environment only)"
}

resource "google_service_account" "app_deploy" {
  project      = var.projects.bootstrap
  account_id   = "mc360-app-deploy"
  display_name = "CareNotes image build and Cloud Run deploy"
}

# Any workflow in the repository may plan.
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.wif_pool}/attribute.repository/${var.github_repository}"
}

# Only jobs running in the protected GitHub environment "production" may apply / deploy.
resource "google_service_account_iam_member" "apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.wif_pool}/subject/${local.prod_env_subject}"
}

resource "google_service_account_iam_member" "app_deploy_wif" {
  service_account_id = google_service_account.app_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.wif_pool}/subject/${local.prod_env_subject}"
}

# State bucket access (works for an existing or a newly created bucket).
resource "google_storage_bucket_iam_member" "state_plan" {
  bucket = var.state_bucket
  role   = "roles/storage.objectUser" # plan needs to take the state lock
  member = "serviceAccount:${google_service_account.plan.email}"

  depends_on = [google_storage_bucket.state]
}

resource "google_storage_bucket_iam_member" "state_apply" {
  bucket = var.state_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.apply.email}"

  depends_on = [google_storage_bucket.state]
}

# Organization roles.
resource "google_organization_iam_member" "apply" {
  for_each = toset(local.apply_org_roles)

  org_id = var.org_id
  role   = each.value
  member = "serviceAccount:${google_service_account.apply.email}"
}

resource "google_organization_iam_member" "plan" {
  for_each = toset(local.plan_org_roles)

  org_id = var.org_id
  role   = each.value
  member = "serviceAccount:${google_service_account.plan.email}"
}

# Project roles for the apply identity on all seven MedCloud360 projects.
resource "google_project_iam_member" "apply" {
  for_each = {
    for pair in setproduct(local.all_project_ids, local.apply_project_roles) :
    "${pair[0]}|${pair[1]}" => { project = pair[0], role = pair[1] }
  }

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.apply.email}"
}

# The plan identity must use the bootstrap project as its quota project.
resource "google_project_iam_member" "plan_quota" {
  project = var.projects.bootstrap
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.plan.email}"
}

# Billing: link usage + create budgets.
resource "google_billing_account_iam_member" "apply_user" {
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.apply.email}"
}

resource "google_billing_account_iam_member" "apply_costs" {
  billing_account_id = var.billing_account
  role               = "roles/billing.costsManager"
  member             = "serviceAccount:${google_service_account.apply.email}"
}

resource "google_billing_account_iam_member" "plan_viewer" {
  billing_account_id = var.billing_account
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${google_service_account.plan.email}"
}

# App deployer: push images and roll out Cloud Run revisions (prod-app + scc-router in observability).
resource "google_project_iam_member" "app_deploy" {
  for_each = {
    "app|ar"  = { project = var.projects.prod_app, role = "roles/artifactregistry.writer" }
    "app|run" = { project = var.projects.prod_app, role = "roles/run.developer" }
    "app|sa"  = { project = var.projects.prod_app, role = "roles/iam.serviceAccountUser" }
    "obs|run" = { project = var.projects.observability, role = "roles/run.developer" }
    "obs|sa"  = { project = var.projects.observability, role = "roles/iam.serviceAccountUser" }
  }

  project = each.value.project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.app_deploy.email}"
}

resource "google_project_iam_member" "app_deploy_quota" {
  project = var.projects.bootstrap
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.app_deploy.email}"
}
