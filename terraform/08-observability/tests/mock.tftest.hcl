# Offline plan test: mocked providers and remote state, no credentials, no cloud calls.
# Run: terraform init -backend=false && terraform test -var-file=../tests/mock.tfvars
mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      email  = "mockaccount@mockproj.iam.gserviceaccount.com"
      name   = "projects/p/serviceAccounts/mockaccount@mockproj.iam.gserviceaccount.com"
      member = "serviceAccount:mockaccount@mockproj.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_logging_organization_sink" {
    defaults = { writer_identity = "serviceAccount:o-1@gcp-sa-logging.iam.gserviceaccount.com" }
  }
  mock_resource "google_iam_workload_identity_pool" {
    defaults = { workload_identity_pool_id = "mc360-github" }
  }
  mock_resource "google_compute_global_address" {
    defaults = { address = "34.1.2.3" }
  }
  mock_resource "google_cloud_run_v2_service" {
    defaults = { uri = "https://svc-abc-uc.a.run.app" }
  }
  mock_data "google_project" {
    defaults = { number = "123456789012" }
  }
  mock_data "google_storage_project_service_account" {
    defaults = { email_address = "service-1@gs-project-accounts.iam.gserviceaccount.com", member = "serviceAccount:service-1@gs-project-accounts.iam.gserviceaccount.com" }
  }
  mock_data "google_bigquery_default_service_account" {
    defaults = { email = "bq-1@bigquery-encryption.iam.gserviceaccount.com", member = "serviceAccount:bq-1@bigquery-encryption.iam.gserviceaccount.com" }
  }
}
mock_provider "google-beta" {
  mock_resource "google_project_service_identity" {
    defaults = { email = "service-1@gcp-sa-x.iam.gserviceaccount.com", member = "serviceAccount:service-1@gcp-sa-x.iam.gserviceaccount.com" }
  }
}
override_data {
  target = data.terraform_remote_state.org
  values = { outputs = {
    project_numbers     = { bootstrap = "111", network = "222", dev = "333", test = "444", observability = "555", prod_app = "666", prod_data = "777" }
    alert_channel_id    = "projects/obs/notificationChannels/1"
    security_log_bucket = "projects/obs/locations/us-central1/buckets/mc360-security-logs"
  } }
}
override_data {
  target = data.terraform_remote_state.network
  values = { outputs = {
    networks          = { for k in ["hub", "security", "prod", "nonprod"] : k => { id = "projects/net/global/networks/mc360-vpc-${k}", name = "mc360-vpc-${k}", self_link = "https://x/${k}" } }
    subnets           = { for k in ["prod-app-usc1", "prod-app-use4"] : k => { id = k, name = k, region = "us-central1", self_link = "https://x/${k}", cidr = "10.42.0.0/22" } }
    internal_dns_zone = "mc360-internal"
    fw_tag_key        = "tagKeys/1"
    fw_tag_values     = { hl7-gw = "tagValues/2", admin = "tagValues/3" }
  } }
}

run "plan_defaults" {
  command = plan
}

run "plan_all_features_enforced" {
  command = plan

  variables {
    enforce_cmek                = true
    vpcsc_dry_run               = false
    enable_hybrid_vpn           = true
    enable_binary_authorization = true
    enable_windows              = true
    create_state_bucket         = true
    access_policy_id            = "123456"
  }
}
