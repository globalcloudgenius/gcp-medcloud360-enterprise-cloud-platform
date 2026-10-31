# Phase 0 · Step 0.1 — Environment Discovery

**Document:** MC360-PH0-01 · **Status:** Verified discovery · **Date:** 2026-10-31 · **Owner:** MedCloud 360 Engineering

## Objective
Establish a reproducible baseline of engineering tools, active GCP identity, accessible organization/projects and billing visibility **without provisioning resources**.

## Commands executed (VS Code / Windows PowerShell)
```powershell
terraform version
gcloud version
git --version
gcloud auth list
gcloud config list
gcloud organizations list
gcloud projects list
gcloud billing accounts list
```

## Observed results
| Check | Recorded result |
| --- | --- |
| Terraform | v1.15.8, Windows AMD64 |
| Google Cloud SDK | 591.0.0; CLI operational |
| Git | 2.55.0.windows.3 |
| CLI identity | Active authenticated Google account (redacted) |
| Organization | One accessible organization identified |
| Projects | Two existing projects discovered; no new project created |
| Billing | One open and one closed billing account visible |
| Installation method | Google Cloud SDK installed with WinGet; exact historical flags not recorded |

## Security and validation
Discovery proves **visibility**, not universal deployment permissions. Account emails, project identifiers and billing IDs are excluded from public evidence. Do not switch the active project or create resources during this assessment.

**Exit criteria:** Tool versions recorded, organization/project inventory reviewed, billing visibility confirmed. **Outcome: Met for discovery scope.**

**Supporting details:** [Original assessment transcript](PHASE0-DISCOVERY-AUTHENTICATION-ARCHIVE.md) · [Phase index](README.md)
