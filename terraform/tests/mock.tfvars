# =============================================================================
# MedCloud360 CareNotes — single configuration file for every Terraform stage.
#
# Do NOT edit this example by hand. Run:
#     ./scripts/discover.sh
# It reads your organization, folders, projects, billing account and Cloud
# Identity customer ID with gcloud and writes config/mc360.tfvars (git-ignored).
# Review the generated file, then run ./scripts/deploy-all.sh.
# =============================================================================

# --- Organization ------------------------------------------------------------
org_id          = "000000000000"
customer_id     = "C00000000" # gcloud organizations describe ORG --format='value(owner.directoryCustomerId)'
org_domain      = "example.com"
billing_account = "000000-000000-000000"

# --- Regions -----------------------------------------------------------------
region    = "us-central1"
dr_region = "us-east4"

# --- Existing folders (never created or changed by this repo) -----------------
folders = {
  bootstrap  = "folders/000000000000"
  networking = "folders/000000000000"
  nonprod    = "folders/000000000000"
  platform   = "folders/000000000000"
  prod       = "folders/000000000000"
  sandbox    = "folders/000000000000"
}

# --- Existing projects (never created or changed by this repo) ----------------
projects = {
  bootstrap     = "mc360-prj-bootstrap"
  network       = "mc360-prj-network"
  dev           = "mc360-prj-dev"
  test          = "mc360-prj-test"
  observability = "mc360-prj-observability"
  prod_app      = "mc360-prj-prod-app"
  prod_data     = "mc360-prj-prod-data"
}

# --- Terraform state ---------------------------------------------------------
state_bucket        = "mc360-bootstrap-tfstate-000000000000"
create_state_bucket = false # true only if the bucket does not exist yet

# --- CI/CD -------------------------------------------------------------------
github_repository = "globalcloudgenius/gcp-medcloud360-enterprise-cloud-platform"

# --- People ------------------------------------------------------------------
# Identities must belong to your Cloud Identity domain when domain restriction is on.
admin_members = ["user:admin@example.com"] # platform admins (break-glass, perimeter access)
iap_members   = ["user:admin@example.com", "group:staff@example.com"]
alert_email   = "admin@example.com"

# --- Feature flags (cost and safe rollout) ------------------------------------
enable_domain_restriction   = true  # iam.allowedPolicyMemberDomains
enforce_cmek                = false # flip to true after stage 03 granted the service agents
vpcsc_dry_run               = true  # flip to false after reviewing dry-run violations
enable_hl7_gateway          = true  # Linux MIG (3 x e2-small) — stop with ./scripts/teardown.sh compute
enable_portal_lb            = true  # global HTTPS LB + Cloud Armor + IAP (~USD 0.60/day)
enable_dr_region            = true  # second Cloud Run region behind the LB
enable_hybrid_vpn           = false # HA VPN lab (~USD 5/day) — enable on demo day only
enable_binary_authorization = false # enforce attested images on Cloud Run (after first CI build)
enable_windows              = false # requires a paid billing account (not available on free trial)

# --- Optional ----------------------------------------------------------------
portal_domain      = "" # empty = <LB IP>.nip.io with a Google-managed certificate
monthly_budget_usd = 10
access_policy_id   = "" # existing org-level Access Context Manager policy number, if any
