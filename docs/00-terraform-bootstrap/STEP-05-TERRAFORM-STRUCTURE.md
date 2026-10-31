# Phase 0 · Step 0.5 — Terraform Repository Structure

**Document:** MC360-PH0-05 · **Status:** Planned; not implemented

## Objective
Organize Terraform as independently deployable foundations and reusable infrastructure modules with predictable reviews and state separation.

## Proposed layout
```text
terraform/
  bootstrap/       # isolated bootstrap root + remote backend
  environments/
    dev/           # separate environment root and state
    nonprod/
    prod/
  modules/
    project-factory/
    iam/
    networking/
    logging/
.github/workflows/ # CI checks and guarded deployment workflows
tests/             # configuration and acceptance tests
```

## Engineering rules
| Area | Standard |
| --- | --- |
| Versions | Pin Terraform and provider constraints; review lockfile changes |
| Modules | Small, documented inputs/outputs; least-privilege defaults |
| State | Separate each root/environment; GCS backend; no sensitive outputs in logs |
| Variables | Typed inputs, validation, nonsecret examples; secrets from approved stores |
| Quality | `terraform fmt -check`, `terraform validate`, lint/security scans as appropriate |
| Git | Ignore state files, local `.terraform` and credentials; do commit provider lockfiles |

## Acceptance evidence
Module structure, validated initialization, clean formatting/validation, approved example plan and state isolation. **Outcome: Pending.**

**Next:** [CI/CD and identity security](STEP-06-CICD-SECURITY.md)
