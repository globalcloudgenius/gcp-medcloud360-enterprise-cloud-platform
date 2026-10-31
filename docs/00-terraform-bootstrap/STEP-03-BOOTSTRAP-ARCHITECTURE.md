# Phase 0 · Step 0.3 — Terraform Bootstrap Readiness & Architecture

**Document:** MC360-PH0-03 · **Version:** 1.3 · **Date:** 2026-10-31 · **Owner:** MedCloud 360 Engineering · **Status:** Readiness verified in part; design approval pending

## Objective

Validate the existing GCP environment and define a **least-privilege, controlled Terraform bootstrap**. Use local Terraform with ADC for initial setup, protected GCS remote state thereafter, and GitHub Actions with OIDC/Workload Identity Federation (WIF) for approved deployments.

## Architecture and deployment approach

| Component | Enterprise design | Execution stage |
| --- | --- | --- |
| Bootstrap project | New dedicated project under an approved organization/folder and billing account | Step 0.4 |
| Terraform execution | VS Code/PowerShell using existing local ADC for controlled bootstrap | Step 0.4 |
| Remote state | Private GCS bucket; uniform access, public access prevention, versioning, restricted IAM and recovery procedure | Step 0.4 |
| Terraform structure | Version-pinned providers, isolated roots/state and reusable modules | Step 0.5 |
| Automation | GitHub Actions: format, validate, scan, plan, review and approved apply | Step 0.6 |
| CI authentication | Restricted GitHub OIDC → GCP WIF → least-privilege deployer service account; no static keys | Step 0.6 |
| Governance | Audit logs, cost review, budget alerts, synthetic data only and sanitized evidence | Steps 0.4–0.7 |

**Sequence:** Validate prerequisites → create bootstrap project and bucket locally → migrate/init GCS backend → test state controls → configure CI/WIF → validate recovery and approved applies. A GCS backend cannot be initialized against a nonexistent bucket.

## Verification results

| Readiness check | Observed result | Status |
| --- | --- | --- |
| Terraform and Cloud SDK | Terraform v1.15.8; Google Cloud SDK 591.0.0 | Verified |
| GCP organization and inventory | One accessible organization; two existing ACTIVE projects | Verified |
| Organization IAM | Active identity directly assigned Project Creator, Billing Admin and Service Usage Admin | Verified |
| Billing | One open USD billing account; active identity directly assigned Billing Admin on account | Verified |
| Local Terraform ADC | Access-token acquisition succeeded without printing token | Verified |
| Proposed project `medcloud360-prj-bootstrap` | Not created; uniqueness not checked | Pending |
| Project creation quota, effective policies and billing association | Not tested end-to-end | Pending |
| Remote state, deployer SA, WIF and CI workflows | Not deployed | Planned |

**Scope note:** A direct IAM role assignment and successful ADC do not guarantee that resource creation will pass effective organization policies, service constraints or quota checks.

## Commands executed — read-only (PowerShell)

```powershell
terraform version
gcloud version
gcloud projects list --format="table(projectId,lifecycleState)"
gcloud organizations get-iam-policy $OrgId --format=json
gcloud billing accounts list --format=json
gcloud billing accounts get-iam-policy $BillingId --format=json
gcloud auth application-default print-access-token 1>$null
```

Organization and billing policy outputs were inspected locally; only sanitized observations are reported here. Project identifiers, administrator emails, credentials and account IDs must not be committed.

## Security controls and acceptance

| Required gate | State |
| --- | --- |
| Approve project placement, creation limits, billing association and initial cost | Open |
| Review state security, initialization/migration and recovery | Open |
| Confirm minimum required IAM and WIF trust boundary | Open |
| Approve PR checks, human review and controlled apply | Open |
| Maintain synthetic-only data and redacted public evidence | Required throughout |

**Outcome:** Initial discovery, direct-role, billing and ADC checks passed; **architecture approval and bootstrap project creation remain pending**.

**Evidence and next steps:** [IAM roles and permissions](IAM-ROLES-AND-PERMISSIONS.md) · [Step 0.2](STEP-02-IAM-BILLING-ADC.md) · [Step 0.4](STEP-04-BOOTSTRAP-DEPLOYMENT.md) · [Phase 0 index](README.md)
