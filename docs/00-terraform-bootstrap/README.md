# Phase 0 — Terraform Bootstrap

**Project:** MedCloud 360 · **Document:** MC360-PH0-INDEX · **Updated:** 2026-10-31

## Purpose

Establish the validated GCP access baseline, secure Terraform state, deployment identities, repeatable CI/CD, and technical acceptance evidence required before building the GCP enterprise landing zone.

## One-page implementation records

| Step | Document | Status | Evidence or exit requirement |
| --- | --- | --- | --- |
| **0.1** | [Environment Discovery](STEP-01-ENVIRONMENT-DISCOVERY.md) | Verified | Workstation tools, organization, project and billing visibility |
| **0.2** | [IAM, Billing & ADC](STEP-02-IAM-BILLING-ADC.md) | Verified | IAM/billing access review and successful local ADC check |
| **0.3** | [Bootstrap Architecture](STEP-03-BOOTSTRAP-ARCHITECTURE.md) | Proposed | Reviewed security, identity, state and deployment design |
| **0.4** | [Bootstrap Deployment](STEP-04-BOOTSTRAP-DEPLOYMENT.md) | Planned | Dedicated project and protected remote state |
| **0.5** | [Terraform Structure](STEP-05-TERRAFORM-STRUCTURE.md) | Planned | Reusable modules, root separation and validation |
| **0.6** | [CI/CD Security](STEP-06-CICD-SECURITY.md) | Planned | Restricted OIDC/WIF, protected plans and approvals |
| **0.7** | [Validation & Evidence](STEP-07-VALIDATION-EVIDENCE.md) | Planned | Repeatability, identity, state, financial and recovery tests |

## Supporting evidence and archive

- [Original detailed Step 0.1–0.2 assessment](PHASE0-DISCOVERY-AUTHENTICATION-ARCHIVE.md) — preserved technical command history, not a new deployment claim.
- [ADC authentication evidence](evidence/PH0-STEP02-ADC-001.md) — sanitized textual record. The previously exposed screenshot was removed from the page; old GitHub attachments may remain accessible.
- [Enterprise engineering evidence register](../04-ENGINEERING-EVIDENCE.md) — project-wide proof and acceptance index.

## Phase acceptance rule

Only mark a step **Verified** when observed evidence supports the stated exit criteria. Proposed architecture and unexecuted plans do not count as deployed resources. Before Step 0.4, review the bootstrap design, organization permissions, billing/quota constraints, state protection and cost controls.

**Current next action:** Review and approve Step 0.3 before provisioning.
