# Runbook — Security detections and incident response

| Alert | Meaning | First 15 minutes |
|---|---|---|
| VPC Service Controls violation | An identity tried to move PHI across the perimeter (blocked when enforced) | SIEM query below → identify principal → if not the self-test: disable the service account, revoke sessions, open SEV-1 |
| Service account key creation attempted | Someone tried to mint a long-lived key (always refused) | Identify principal; confirm intent; coach or contain |
| Organization policy changed | Guardrail weakened or strengthened | Confirm a merged PR exists; if not → revert with `tf.sh 01-org apply` |
| IAM policy changed | Access changed | Compare with Terraform plan (drift); unexpected → revert and investigate |
| Firewall policy or rule changed | Network exposure changed | Effective firewall view; unexpected → revert via stage 02 |
| Portal 5xx / SLO burn | Users affected | Cloud Run revision logs; roll back traffic to previous revision |

## SIEM queries (BigQuery, `mc360-prj-observability.org_audit_siem`)

```sql
-- VPC-SC violations, last 24h
SELECT timestamp,
       protopayload_auditlog.authenticationInfo.principalEmail AS who,
       protopayload_auditlog.methodName AS method,
       JSON_VALUE(protopayload_auditlog.metadataJson, '$.violationReason') AS reason
FROM `mc360-prj-observability.org_audit_siem.cloudaudit_googleapis_com_policy`
WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY timestamp DESC;

-- Who read PHI (Data Access logs on mc360-prj-prod-data)
SELECT timestamp, protopayload_auditlog.authenticationInfo.principalEmail AS who,
       protopayload_auditlog.methodName, protopayload_auditlog.resourceName
FROM `mc360-prj-observability.org_audit_siem.cloudaudit_googleapis_com_data_access`
WHERE timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
ORDER BY timestamp DESC LIMIT 100;
```

## Containment commands

```bash
gcloud iam service-accounts disable SA_EMAIL --project PROJECT        # stop a compromised workload identity
gcloud run services update-traffic carenotes-portal --to-revisions=PREV=100 --region us-central1 --project mc360-prj-prod-app
./scripts/enforce-guardrails.sh                                        # make sure the perimeter is enforced
```

Post-incident: blameless postmortem within 5 business days; add the missing guardrail; update this runbook.
