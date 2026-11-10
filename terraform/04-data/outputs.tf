output "buckets" {
  value = { for k, v in google_storage_bucket.b : k => v.name }
}

output "topics" {
  value = { for k, v in google_pubsub_topic.t : k => v.id }
}

output "dataset" {
  value = google_bigquery_dataset.carenotes.dataset_id
}

output "dlp_templates" {
  value = {
    inspect    = google_data_loss_prevention_inspect_template.phi.id
    deidentify = google_data_loss_prevention_deidentify_template.phi.id
  }
}
