# Runbook — Reliability, DR and break-it drills

## Recovery objectives

| Workload | Design | RTO | RPO |
|---|---|---|---|
| CareNotes portal | Cloud Run in us-central1 + us-east4 behind one global LB | ~1 min (LB health) | 0 (stateless) |
| Processor + pipeline | Pub/Sub retries + dead-letter topic; idempotent BigQuery inserts (row id = note id) | 15 min | 0 (messages retained 7 days) |
| HL7 gateway | Regional MIG, 3 zones, autohealing; senders retry on missing ACK | ~5 min (zone loss: 0) | 0 (ACK only after Pub/Sub accepts) |
| PHI data | GCS versioning, BigQuery time travel (7 days), daily VM snapshots | 4 h | 24 h (snapshots), minutes (GCS/BQ) |

## Drills (run, time, screenshot)

| # | Drill | How | Expected | Fix |
|---|---|---|---|---|
| 1 | Region failure | `gcloud run services update carenotes-portal --region us-central1 --project mc360-prj-prod-app --update-env-vars CHAOS_FAIL=true` | After a few 503s, LB outlier detection ejects us-central1; header shows "served from us-east4" | `--remove-env-vars CHAOS_FAIL` |
| 2 | Zone failure | Delete the VMs in one zone of `hl7-gw-mig` | MIG recreates them; HL7 sends keep getting AA | Automatic |
| 3 | Firewall break | Remove rule priority 1000 in `mc360-fwp-prod` | HL7 job fails; Connectivity Test shows the deny | `tf.sh 02-network apply` |
| 4 | CMEK grant missing | Remove the storage agent's KMS grant | Uploads fail with a KMS permission error | `tf.sh 03-security apply` |
| 5 | Perimeter lock-out | Remove CI identities from the ingress rule, enforce | CI plan fails with "Request is prohibited by organization's policy" | Re-apply stage 07 (ACM API is not restricted) |
| 6 | IAP denial | Open the portal as a user not in `iap_members` | 403 from IAP; request never reaches Cloud Run | Add the member, apply 06 |
| 7 | VPN tunnel loss (VPN lab on) | Delete `mc360-hub-to-clinic-t0` | Traffic continues on t1 after BGP hold time | `tf.sh 02-network apply` |

## Performance pass

1. Baseline: `hey -z 2m -c 20 https://PORTAL/healthz` with an IAP-authorized identity, or Locust against `/`.
2. Read p50/p95 on the dashboard. Tune `max_instance_request_concurrency` and `min_instance_count` in stage 06.
3. HL7: run the job with `HL7_COUNT=1000`; watch the MIG autoscaler (target 60 % CPU).
4. Apply Recommender rightsizing for the HL7 VMs; record before/after.
