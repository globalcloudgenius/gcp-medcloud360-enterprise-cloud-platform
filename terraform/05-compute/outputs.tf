output "hl7_endpoint" {
  value = var.enable_hl7_gateway ? "hl7.mc360.internal:2575 (${local.hl7_ip}) — MLLP over TLS" : "disabled"
}

output "hl7_mig" {
  value = var.enable_hl7_gateway ? google_compute_region_instance_group_manager.hl7[0].name : null
}

output "hl7_ip" {
  value = local.hl7_ip
}

output "patch_deployment" {
  value = google_os_config_patch_deployment.linux_weekly.name
}
