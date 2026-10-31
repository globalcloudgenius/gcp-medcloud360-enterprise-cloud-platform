# 04 — Engineering Evidence and Validation Register

## Purpose

Maintain traceable evidence for cloud-engineering decisions, access verification, change reviews, security tests and operations. Only sanitized evidence is appropriate in this public repository.

## Evidence register

| ID | Phase / step | Record | Verified outcome | Link |
| --- | --- | --- | --- | --- |
| PH0-STEP01 | Phase 0 / 0.1 | Windows tooling, GCP organization/project and billing discovery | CLI/tool versions and resource visibility established | [Phase 0 assessment](00-terraform-bootstrap/README.md) |
| PH0-STEP02 | Phase 0 / 0.2 | Organization IAM, billing IAM and local ADC validation | Role assignments observed; billing account open; ADC token check passed | [Phase 0 assessment](00-terraform-bootstrap/README.md) |
| PH0-STEP02-ADC-001 | Phase 0 / 0.2 | OAuth consent screen observation and ADC login | Consent flow documented and local ADC verification recorded | [ADC evidence](00-terraform-bootstrap/evidence/PH0-STEP02-ADC-001.md) |

## Required evidence fields

| Field | Requirement |
| --- | --- |
| Identifier | Unique phase/step evidence ID |
| Context | Scope, purpose, environment and command/tool versions |
| Execution | Sanitized commands, test procedure and relevant configuration |
| Outcome | Expected vs. actual results, status and limitations |
| Control | Reviewer, follow-up actions and security/data handling |
| Traceability | Links to code, diagrams, logs or test artifacts where available |

## Evidence publication standards

- Never publish raw ADC credential files, OAuth state parameters, secrets, tokens, billing identifiers or sensitive IAM membership.
- Remove personal identifiers from screenshots **before uploading**. Deleting a Markdown image link does not erase earlier GitHub user attachments or commit history.
- Do not treat a consent screen as proof of access authorization; pair it with independent authentication and IAM checks.
- Record tested versus proposed infrastructure separately.
- Maintain phase evidence under `docs/NN-phase-name/` and `docs/NN-phase-name/evidence/`.

**Next review:** Phase 0 Step 0.3 — bootstrap architecture, permissions, quotas and financial guardrails.
