# Phase 0 · Step 0.3 — Enterprise Terraform Bootstrap Design

**Document:** MC360-PH0-03 · **Version:** 1.1 · **Status:** Design proposed; validation pending · **Date:** 2026-10-31

## Objective and scope
Approve a **low-cost, secure Terraform foundation** for MedCloud 360 before provisioning the GCP landing zone. Terraform will run **locally in VS Code for initial bootstrap**, use **GCS remote state** after backend creation, and transition to **GitHub Actions with OIDC/Workload Identity Federation (WIF)** for reviewed deployments.

## Target architecture and resources
```text
Engineer / VS Code + Terraform + local ADC  ── initial bootstrap
                         │
                         ▼
Dedicated GCP bootstrap project ── GCS state bucket (private, versioned)
                         ▲
                         │  authorized state access
GitHub PR → fmt/validate/scan → plan → approval → apply
                         │
                         └── GitHub OIDC → GCP WIF → deployer service account
                                      │
                                      └── Governed GCP target projects (later phases)
```

| Component | Proposed implementation and enterprise control |
| --- | --- |
| GCP project | Dedicated bootstrap project under approved organization/folder; validate unique ID, quota and billing association |
| State backend | Private GCS bucket; uniform bucket-level access, public access prevention, object versioning, tightly scoped IAM, encryption at rest and recovery procedure |
| Deployment identities | Human ADC for initial administration; separate least-privilege Terraform service account for automation |
| CI/CD | GitHub Actions with scoped OIDC/WIF trust, protected branch, required checks and approval before apply; no service-account JSON keys |
| Governance | Audit logs, resource labels, cost visibility, budget alerts (**not spending caps**), sanitized evidence |
| Workloads | **None in this step**; landing-zone, VPC, Palo Alto, Azure and data services are delivered in later phases |

## Enterprise deployment sequence (Steps 0.4–0.7)
1. **Validate** organization permissions, billing access, APIs, quotas, bucket location, costs and allowed GitHub authentication conditions.
2. **Bootstrap locally:** create the dedicated project and protected state bucket using a controlled initial operation. **Do not configure the GCS backend until the bucket exists.**
3. **Migrate and verify state:** initialize the GCS backend, migrate initial state where applicable, verify locking/access controls and test recovery. Never commit local or remote state.
4. **Automate:** configure a dedicated deployer identity, GitHub WIF and PR checks; require human approval for apply and isolate environment state.
5. **Validate:** test permitted/denied IAM, reproducible plan, audit evidence, budget notifications and rollback/recovery; capture sanitized results.

## Non-destructive predeployment checks (PowerShell)
```powershell
terraform version
gcloud version
gcloud auth list
gcloud config list
gcloud organizations list
gcloud projects list
gcloud billing accounts list
gcloud auth application-default print-access-token 1>$null
if ($LASTEXITCODE -eq 0) { "ADC token acquisition: PASS" }
else { "ADC token acquisition: FAIL" }
```
These commands confirm tool availability, resource visibility and local ADC **only**. Do not paste raw identities or billing/project identifiers into public evidence. Neither they nor successful ADC establish authorization to create all proposed resources.

## Design approval / exit criteria
- [ ] Project placement, account permissions, billing/quota and preliminary cost approved.
- [ ] Backend security, bootstrap/migration sequence and state recovery reviewed.
- [ ] Least-privilege CI identity, WIF restrictions and deployment approvals agreed.
- [ ] No real PII/PHI or credentials in GitHub; synthetic healthcare data only.
- [ ] Ownership and test/evidence plan accepted.

**Outcome:** Design documented, **not yet approved or deployed**. No provisioning commands run by this document.  
**Next:** [Step 0.4 — Bootstrap Deployment](STEP-04-BOOTSTRAP-DEPLOYMENT.md) · [Phase 0 Index](README.md) · [Security and privacy controls](../governance/PRIVACY-AND-CONTROL-FRAMEWORKS.md)
