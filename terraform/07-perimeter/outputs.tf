output "access_policy" {
  value = local.policy
}

output "perimeter" {
  value = google_access_context_manager_service_perimeter.phi.name
}

output "mode" {
  value = var.vpcsc_dry_run ? "DRY RUN — violations are logged, nothing is blocked" : "ENFORCED"
}

output "dry_run_violations_query" {
  description = "Paste into Logs Explorer (scope: organization) to review before enforcing."
  value       = "protoPayload.metadata.@type=\"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata\" AND protoPayload.metadata.dryRun=true"
}
