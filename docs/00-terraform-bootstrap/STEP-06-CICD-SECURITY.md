# Phase 0 · Step 0.6 — CI/CD and Deployment Security

**Document:** MC360-PH0-06 · **Status:** Planned; not implemented

## Objective
Enable secure, reviewable and auditable Terraform changes through GitHub Actions without static cloud-service-account keys.

## Planned pipeline
| Trigger / stage | Control | Evidence |
| --- | --- | --- |
| Pull request | Format, validate and IaC security checks | CI status and findings |
| Pull request | Terraform plan with restricted credentials | Redacted plan review |
| Merge to protected branch | Required reviewers and checks | Branch-rule evidence |
| Apply | Environment approval; approved plan artifact with controlled expiry | Reviewer and deployment log |
| Cloud authentication | GitHub OIDC → GCP WIF → limited deployer account | IAM and token exchange verification |
| Post-deploy | State, configuration and access checks | Acceptance test logs |

## Required safeguards
Constrain WIF to the intended GitHub owner/repository and approved branch/environment claims. Use minimal GitHub token permissions and narrowly scoped GCP IAM. Protect the environment with approval reviewers, prevent overlapping applies, and protect any plan artifacts containing sensitive values. Configure destroy operations as separate explicitly approved workflows, not automatic merge actions.

**Exit criteria:** CI validation, federation, protected plan/apply and negative-permission tests demonstrated. **Outcome: Pending.**

**Next:** [Validation and evidence](STEP-07-VALIDATION-EVIDENCE.md)
