output "portal_url" {
  description = "Open in a browser (certificate provisioning can take 15-60 minutes after first apply)."
  value       = var.enable_portal_lb ? "https://${local.domain}" : "load balancer disabled"
}

output "image" {
  description = "Image path CI pushes to."
  value       = local.image
}

output "processor_url" {
  value = google_cloud_run_v2_service.processor.uri
}

output "selftest_outside_bucket" {
  value = google_storage_bucket.outside.name
}

output "cloud_run_services" {
  value = concat(
    [for r, s in google_cloud_run_v2_service.portal : "${s.name}@${r}"],
    ["${google_cloud_run_v2_service.processor.name}@${var.region}", "scc-router@${var.region}"],
  )
}
