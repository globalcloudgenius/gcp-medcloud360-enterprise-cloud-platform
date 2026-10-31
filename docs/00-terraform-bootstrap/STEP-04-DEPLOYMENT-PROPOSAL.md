# Phase 0 · Step 0.4 — Terraform Bootstrap Deployment Proposal

| Document control | Value |
| --- | --- |
| ID / Version | MC360-PH0-04-PROP / 1.0 |
| Status | **Proposed — awaiting review; no deployment executed** |
| Date | 2026-10-31 |
| Owner | MedCloud 360 Engineering |
| Approach | Local Terraform + ADC → GCS backend → GitHub Actions OIDC/WIF |

## Objective and scope

Deploy the **minimum secure GCP foundation** for subsequent MedCloud 360 phases. Keep existing GCP projects unchanged. The first deployment is limited to a dedicated bootstrap project, required APIs, a protected state bucket and supporting governance controls; GitHub automation and wider landing-zone infrastructure follow only after initial acceptance.

## Proposed resources

| Resource | Purpose | Security / cost requirement |
| --- | --- | --- |
| Dedicated GCP project | Isolate Terraform control plane | Proposed ID `medcloud360-prj-bootstrap`; validate global uniqueness, placement and quota |
| Project billing association | Permit approved resource creation | Verified open USD billing account; validate effective project billing permissions |
| Foundational APIs | Enable Resource Manager, IAM, Service Usage, Cloud Storage as required | Only enable APIs necessary for bootstrap |
| Private GCS state bucket | Store Terraform state centrally | Uniform bucket-level access; public access prevention; versioning; minimal IAM; lifecycle/recovery review |
| Deployment service account | Terraform automation identity | Least-privilege roles; no service-account key files |
| Budget/alerts and audit | Cost visibility and accountability | Budget notifications **are not hard caps**; avoid sharing identifiers in GitHub |
| WIF & GitHub Actions (subsequent step) | Keyless, reviewed deployments | Restrict repository identity, branch/environment, audience and impersonation permissions |

## Deployment plan and control gates

| Gate | Planned action | Required evidence |
| --- | --- | --- |
| 1 — Readiness | Verify organization/folder placement, creation quota, effective policies, billing association and estimated charges | Redacted check results and go/no-go approval |
| 2 — Controlled bootstrap | From VS Code/PowerShell, create the project and GCS state bucket using locally authenticated administrative credentials in an approved bootstrap root or controlled seed procedure | Resource names and bucket security checks (identifiers redacted in public files) |
| 3 — State migration | Add GCS backend after bucket creation; `terraform init -migrate-state` **only if existing state requires migration** | Successful init, bucket-scoped access and state-lock/recovery test |
| 4 — Identity | Create dedicated deployer service account and scope Terraform/state permissions to required resources | Role assignments and negative-permission checks |
| 5 — Automation | Configure restricted GitHub OIDC/WIF, PR checks and protected apply approvals in Step 0.6 | CI logs and reviewed plan/apply |
| 6 — Acceptance | Test repeatable plan, logging, recovery, budget visibility and teardown | Evidence linked in [engineering register](../evidence/ENGINEERING-EVIDENCE.md) |

## Operator preparation — read-only PowerShell

```powershell
# Run from VS Code PowerShell. These commands do not create resources.
terraform version
gcloud version
gcloud auth list --filter="status:ACTIVE" --format="table(status)"
gcloud projects list --format="table(lifecycleState)"
gcloud billing accounts list --format="table(open,currencyCode)"
gcloud auth application-default print-access-token 1>$null
if ($LASTEXITCODE -ne 0) { throw "ADC authentication not ready" }
```

**Execution prerequisites:** Check project-creation quota and effective organization-policy restrictions separately; the project inventory command is not a quota check. The bootstrap folder and final bucket name must be agreed before deployment. Terraform and Google provider versions will be pinned before the first apply. No `gcloud projects create`, billing linkage, service enablement or `terraform apply` is authorized by this proposal alone.

## Review and rollback plan

- **Approval:** Confirm project ID, intended parent, billing account, cost ceiling/alerts, temporary admin privileges, bucket location, WIF trust boundaries and reviewer.
- **Rollback:** If project creation succeeds but state setup fails, preserve any state, inspect resources and billing, then perform a reviewed cleanup. Do not blindly delete state or the project.
- **Privacy:** No real PII/PHI; synthetic data only. Never commit token output, state files, credential JSON, raw IAM member lists or billing IDs.
- **Scope boundary:** No Palo Alto appliances, Cloud SQL HA, VMs, VPNs, Azure resources or production workloads in this change.

**Decision:** **No-go until** creation constraints, billing linkage, bootstrap design and financial safeguards are approved.

**Related:** [Step 0.3 readiness & design](STEP-03-BOOTSTRAP-ARCHITECTURE.md) · [IAM roles & permissions](IAM-ROLES-AND-PERMISSIONS.md) · [Phase 0 index](README.md)
