output "workload_identity_provider" {
  description = "Value for the GitHub variable GCP_WIF_PROVIDER."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "plan_service_account" {
  description = "Value for the GitHub variable GCP_PLAN_SA."
  value       = google_service_account.plan.email
}

output "apply_service_account" {
  description = "Value for the GitHub variable GCP_APPLY_SA."
  value       = google_service_account.apply.email
}

output "app_deploy_service_account" {
  description = "Value for the GitHub variable GCP_APP_DEPLOY_SA."
  value       = google_service_account.app_deploy.email
}

output "state_bucket" {
  value = var.state_bucket
}

output "github_setup_commands" {
  description = "Run these once (gh CLI) to wire the repository to GCP."
  value       = <<-EOT
    gh variable set GCP_WIF_PROVIDER  --body "${google_iam_workload_identity_pool_provider.github.name}"
    gh variable set GCP_PLAN_SA       --body "${google_service_account.plan.email}"
    gh variable set GCP_APPLY_SA      --body "${google_service_account.apply.email}"
    gh variable set GCP_APP_DEPLOY_SA --body "${google_service_account.app_deploy.email}"
    gh variable set GCP_STATE_BUCKET  --body "${var.state_bucket}"
    gh secret   set MC360_TFVARS      < config/mc360.tfvars
  EOT
}
