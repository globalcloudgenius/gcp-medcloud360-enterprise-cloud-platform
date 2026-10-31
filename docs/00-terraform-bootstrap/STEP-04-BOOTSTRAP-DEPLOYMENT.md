# Phase 0 · Step 0.4 — Bootstrap Project and State Deployment

**Document:** MC360-PH0-04 · **Status:** Planned; not executed

## Objective
Provision a dedicated GCP bootstrap project, foundational APIs and a protected Terraform state backend.

## Implementation sequence
| Order | Activity | Verification |
| --- | --- | --- |
| 1 | Confirm effective project-creation IAM, quotas, organization policies and billing permissions | Access and constraints checked |
| 2 | Create dedicated bootstrap project and associate approved billing account | Correct project parent and billing |
| 3 | Enable required APIs (e.g., Cloud Resource Manager, IAM, Service Usage, Cloud Storage where applicable) | API state recorded |
| 4 | Bootstrap a private, versioned GCS state bucket with restricted IAM and public access prevention | Bucket settings validated |
| 5 | Initialize Terraform backend and migrate initial state in a controlled operation | `terraform init -migrate-state` succeeds where applicable |
| 6 | Test state access, locking behavior and recovery, then document budget guardrails | Signed-off test evidence |

## Controls and constraints
The state bucket cannot serve as a backend before it exists: provision it using an explicitly controlled bootstrap procedure. Do not delete working state, expose state in GitHub or presume budget alerts prevent all charges. Use explicit project targeting; verify no existing sandbox project is modified.

**Exit criteria:** Bootstrap project, secure state and billing configuration validated with sanitized evidence. **Outcome: Pending.**

**Previous:** [Architecture](STEP-03-BOOTSTRAP-ARCHITECTURE.md) · **Next:** [Terraform structure](STEP-05-TERRAFORM-STRUCTURE.md)
