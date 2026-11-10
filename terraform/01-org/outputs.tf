output "project_numbers" {
  value = { for k, p in data.google_project.p : k => p.number }
}

output "siem_dataset" {
  value = "${var.projects.observability}.${google_bigquery_dataset.siem.dataset_id}"
}

output "security_log_bucket" {
  value = google_logging_project_bucket_config.security.id
}

output "audit_archive_bucket" {
  value = google_storage_bucket.audit_archive.name
}

output "alert_channel_id" {
  value = google_monitoring_notification_channel.email.id
}

output "org_policies" {
  value = concat(
    [for p in google_org_policy_policy.boolean : p.name],
    [google_org_policy_policy.vm_external_ip.name, google_org_policy_policy.resource_locations.name,
    google_org_policy_policy.run_ingress.name],
  )
}
