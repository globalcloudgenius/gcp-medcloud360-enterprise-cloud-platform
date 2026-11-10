output "dashboard" {
  value = "https://console.cloud.google.com/monitoring/dashboards?project=${var.projects.observability}"
}

output "connectivity_tests" {
  value = { for k, t in google_network_management_connectivity_test.isolation : k => t.name }
}

output "slo" {
  value = google_monitoring_slo.portal_availability.id
}
