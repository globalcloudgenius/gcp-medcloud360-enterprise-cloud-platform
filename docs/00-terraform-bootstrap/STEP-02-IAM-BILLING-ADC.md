# Phase 0 · Step 0.2 — IAM, Billing and Terraform ADC

**Document:** MC360-PH0-02 · **Status:** Verified checks · **Date:** 2026-10-31 · **Owner:** MedCloud 360 Engineering

## Objective
Validate organization permissions, billing-account access and local Application Default Credentials (ADC) for Terraform, while avoiding public disclosure of identifiers and access tokens.

## Commands executed (replace placeholders locally)
```powershell
$OrgId = "<ORG_ID>"
$BillingId = "<OPEN_BILLING_ACCOUNT_ID>"
gcloud organizations get-iam-policy $OrgId --format=json
gcloud billing accounts describe $BillingId
gcloud billing accounts get-iam-policy $BillingId --format=json
gcloud auth application-default print-access-token 1>$null
# Initial check failed because local ADC was absent
gcloud auth application-default login
gcloud auth application-default print-access-token 1>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Terraform ADC verified successfully"
} else {
    Write-Host "Terraform ADC verification failed"
}
```

## Verified results
| Test | Recorded observation |
| --- | --- |
| Organization IAM | Roles included organization administration, project creation/movement, billing and Service Usage administration |
| Billing status | Open billing account; currency USD |
| Billing IAM | Billing administrator role observed |
| First ADC check | Failed: default credentials not found |
| Interactive OAuth login | Completed; local ADC credentials written to workstation |
| Final ADC check | **Terraform ADC verified successfully** |

## Boundaries and security
Local ADC token acquisition **does not prove all APIs or project-creation operations are authorized**. Never publish OAuth URLs, tokens, credential JSON or personal emails. The consent screenshot was removed from the public record because it contained an identifier; removing a reference does not delete prior GitHub attachments.

**Exit criteria:** Org/billing IAM reviewed and local ADC token retrieval verified. **Outcome: Met for the checks performed.**

**Evidence:** [ADC evidence record](evidence/PH0-STEP02-ADC-001.md) · [Original assessment transcript](PHASE0-DISCOVERY-AUTHENTICATION-ARCHIVE.md)
