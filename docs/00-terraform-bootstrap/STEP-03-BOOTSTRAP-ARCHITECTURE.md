# Phase 0 · Step 0.3 — Terraform Bootstrap Architecture

**Document:** MC360-PH0-03 · **Status:** Proposed / awaiting design review · **Date:** 2026-10-31

## Objective
Define a secure control plane for repeatable GCP infrastructure delivery **before creating paid resources**.

## Logical design
```text
GitHub pull request → validate / scan / Terraform plan
                   → human approval → controlled Terraform apply
                   → GitHub OIDC → GCP Workload Identity Federation
                   → restricted Terraform deployer service account
                   → GCP bootstrap project + protected GCS remote state
                   → separately governed target projects
```

## Design decisions to validate
| Domain | Proposed requirement |
| --- | --- |
| Bootstrap project | Dedicated project under approved organization/folder; project ID availability to be checked |
| Billing | Approved open billing account; budget alerts (not hard spending caps) |
| Terraform backend | Dedicated GCS bucket, versioning, uniform bucket-level access, public access prevention, restricted IAM |
| State recovery | Controlled first-time creation, migration to GCS, restore/recovery test; never commit local state |
| CI identity | GitHub OIDC and GCP Workload Identity Federation; no long-lived service account keys |
| Access control | Least-privilege deployer, protected branches and approved apply |
| Audit | Change history, Cloud Audit Logs, deployment records, sanitized evidence |
| Cost | Quota and marketplace licensing review before costly resources |

## Architecture review gate
Confirm organization/project creation rights, state bucket location, billing scope, identity trust restrictions, security controls, initial resource cost and rollback ownership. **No implementation is asserted in this document.**

**Exit criteria:** Design and constraints reviewed; bootstrap deployment plan approved. **Outcome: Pending.**

**Next:** [Step 0.4](STEP-04-BOOTSTRAP-DEPLOYMENT.md)
