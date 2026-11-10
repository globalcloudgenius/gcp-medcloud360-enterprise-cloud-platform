output "kms_keys" {
  value = { for k, v in google_kms_crypto_key.key : k => v.id }
}

output "service_accounts" {
  value = merge(
    { for k, v in google_service_account.app : k => v.email },
    { scc-router = google_service_account.scc_router.email, selftest-target = google_service_account.selftest_target.email },
  )
}

output "secrets" {
  value = { for k, v in google_secret_manager_secret.s : k => v.secret_id }
}

output "scc_topic" {
  value = google_pubsub_topic.scc_findings.id
}

output "hl7_ca_cert_pem" {
  value = tls_self_signed_cert.ca.cert_pem
}
