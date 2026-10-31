# Phase 0 · Step 0.3 — Enterprise Terraform Bootstrap Readiness & Design

| Document control | Value |
| --- | --- |
| Document ID | MC360-PH0-03 |
| Version | 1.2 |
| Date | 2026-10-31 |
| Owner | MedCloud 360 Engineering |
| Status | **Readiness partially verified; design approval pending** |
| Scope | Read-only GCP assessment and proposed Terraform bootstrap architecture |

## Objective
Validate the GCP organization, active projects, account permissions, billing and local Terraform authentication before deploying a **dedicated** bootstrap project. Use local Terraform for initial setup, protected **GCS remote state** for ongoing operations, and GitHub Actions with **OIDC/WIF** for controlled automation.

## Verification results — observed PowerShell output

| Control / test | Verified observation | Status |
| --- | --- | --- |
| Terraform / Google Cloud SDK | Terraform v1.15.8; Google Cloud SDK 591.0.0 | **Pass** |
| GCP organization | One accessible organization listed | **Pass** |
| Existing projects | **Two ACTIVE projects** listed; neither identified as the MedCloud 360 bootstrap | **Pass — inventory only** |
| Organization IAM | Direct assignments: `roles/resourcemanager.projectCreator`, `roles/billing.admin`, `roles/serviceusage.serviceUsageAdmin` | **Pass — direct bindings** |
| Billing account | One **open**, USD-denominated account; direct `roles/billing.admin` assignment on that account | **Pass** |
| Local Terraform ADC | Access-token acquisition returned success; token not printed | **Pass** |
| Dedicated bootstrap project | `medcloud360-prj-bootstrap` is a **proposed ID**, not created or checked for availability | **Pending** |
| Project-creation quota / org policies | Effective quotas and blocking organization constraints not tested | **Pending** |
| Remote Terraform state / CI/CD | No state bucket, WIF provider or pipeline deployed as part of this step | **Planned** |

> **Interpretation:** Organization-level project-creator and billing roles establish strong initial prerequisites, **not proof that a new project can be created and billed**. The `gcloud projects list` command is an inventory check, not a quota check.

## Proposed deployment architecture

| Component | Enterprise design and guardrails |
| --- | --- |
| Bootstrap project | New isolated GCP project under approved organization/folder, associated with approved billing |
| Terraform execution | VS Code/PowerShell + local ADC for first bootstrap; reviewed automation thereafter |
| Remote state | Private GCS bucket: uniform access, public access prevention, versioning, restricted IAM, encrypted storage and recovery test |
| Automation identity | Dedicated least-privilege deployer service account; GitHub OIDC → GCP Workload Identity Federation |
| CI/CD | Pull request → format/validate/security checks → plan → authorized approval → apply |
| Governance | Audit logging, separate environment state, budget alerts, documented changes and evidence redaction |
| Data protection | Synthetic healthcare data only; **no real PII/PHI, credentials, state files or billing IDs** in GitHub |

## Read-only validation commands used

```powershell
terraform version
gcloud version
gcloud projects list --format="table(projectId,lifecycleState)"
gcloud organizations get-iam-policy $OrgId --format=json
gcloud billing accounts list --format=json
gcloud billing accounts get-iam-policy $BillingId --format=json
gcloud auth application-default print-access-token 1>$null
```

The role checks compared policy members against the active account locally; their **boolean results**, not identities or account numbers, are reported above. The final ADC check returned success. The installed `gcloud alpha projects list` command also listed two existing projects; it does **not** validate creation quota.

## Design gate and next action

| Required before Step 0.4 | State |
| --- | --- |
| Confirm target organization/folder, unique bootstrap project ID and effective creation constraints | **Open** |
| Confirm project-creation quota, organization policies, billing association permissions and initial costs | **Open** |
| Approve GCS bootstrap/migration process, identity restrictions, deployment reviews and recovery plan | **Open** |
| Create bootstrap project, state bucket, CI identity or GitHub workflow | **Not yet executed** |

**Conclusion:** Read-only identity, billing and ADC prerequisites were successfully verified. **Step 0.3 is not yet fully approved, and the bootstrap project has not been created.**

**Next:** [Step 0.4 — Controlled Bootstrap Deployment](STEP-04-BOOTSTRAP-DEPLOYMENT.md) · [Phase 0 Index](README.md) · [Privacy and Control Frameworks](../governance/PRIVACY-AND-CONTROL-FRAMEWORKS.md)
