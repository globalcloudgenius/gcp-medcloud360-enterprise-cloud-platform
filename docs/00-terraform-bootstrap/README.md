# Phase 0 — Enterprise Cloud Foundation Bootstrap & IaC Enablement

## Step 0.1 — GCP Environment Discovery and Prerequisite Assessment

**Assessment date:** 2026-10-31  
**Project:** MedCloud 360 — Enterprise GCP-First Hybrid Cloud Platform  
**Assessment type:** Read-only, workstation and cloud-environment discovery  
**Result:** Initial discovery completed; authorization and cost validation pending  
**Change impact:** None — discovery commands only

### Executive summary

The first bootstrap assessment establishes a baseline for the engineering workstation, Google Cloud CLI identity, accessible organization, existing projects, and billing-account visibility. Terraform, Google Cloud CLI, and Git are installed and callable. One GCP organization and two existing projects are visible to the active CLI identity. The billing listing returns one **open** and one **closed** billing account.

These findings establish **visibility**, not provisioning authorization. They do not establish project/folder creation permissions, billing association rights, active trial credits, available quotas, Terraform Application Default Credentials, or deployment readiness. No resources were created or modified.

### Workstation setup — Google Cloud CLI with WinGet and VS Code

Google Cloud CLI was installed on the Windows engineering workstation using **Windows Package Manager (WinGet)**. The environment was then accessed and validated using a **PowerShell terminal in Visual Studio Code (VS Code)**.

The following is the **documented, reproducible installation command** for the WinGet package `Google.CloudSDK` (the precise historical command flags were not captured in the original terminal evidence):

```powershell
# Run in VS Code > Terminal > New Terminal (PowerShell)
winget install --id Google.CloudSDK --exact
```

After installation, restart the VS Code terminal to refresh the PATH, then verify the command-line tools:

```powershell
gcloud version
gcloud auth list
gcloud config list
```

| Setup item | Method / observation | Verification |
| --- | --- | --- |
| Workstation operating system | Windows; PowerShell shell | Observed from the supplied terminal session |
| Development interface | Visual Studio Code with integrated PowerShell terminal | Workstation workflow reported by the project engineer |
| Google Cloud CLI installation | Windows Package Manager (WinGet), package ID `Google.CloudSDK` | Installation method reported by the project engineer; exact historical command not captured |
| Installed SDK | Google Cloud SDK **591.0.0** | Verified by `gcloud version` |
| Account context | CLI had two credentialed accounts, one active | Verified by `gcloud auth list`; email addresses not published |
| Active project context | Default configuration pointed at an existing GCP project | Verified by `gcloud config list`; project ID not published |

**Separation of evidence:** The WinGet installation method and VS Code use are project-engineer-reported setup details. The actual SDK version and cloud account/configuration observations are supported by captured terminal output. This distinction avoids presenting an unrecorded installation command as a verbatim executed command.

### Commands executed — Step 0.1

The following commands were executed from **Windows PowerShell** to capture the initial tooling, authentication-context, organization, project, and billing visibility baseline. These commands are **read-only** and can be rerun by an authorized engineer.

```powershell
# 1. Local infrastructure tooling
terraform version
gcloud version
git --version

# 2. Active Google Cloud CLI identity and configuration
gcloud auth list
gcloud config list

# 3. Discover accessible GCP organization and projects
gcloud organizations list
gcloud projects list

# 4. Discover visible billing accounts and status
gcloud billing accounts list
```

**Observed results (sanitized):** Terraform 1.15.8; Google Cloud SDK 591.0.0; Git 2.55.0.windows.3; two credentialed CLI accounts with one active; one visible organization; two existing projects; and two visible billing accounts (one open, one closed).

**Evidence interpretation:** The commands establish discoverability and installed versions; they do **not** verify IAM provisioning rights, project billing linkage, credit availability, or Terraform ADC. Redact personal email addresses, detailed project and billing identifiers, and IAM membership from any public terminal captures.

### Captured command results — Step 0.1

The following tables present the **actual observed command output** in a review-friendly format. Sensitive personal identifiers, project IDs, project numbers, and billing account IDs are intentionally redacted from this public repository; original records can be retained privately.

#### A. Local engineering tools

| Command | Observed result | Additional detail | Outcome |
| --- | --- | --- | --- |
| `terraform version` | **Terraform v1.15.8** | `windows_amd64`; Terraform reported v1.17.1 as the latest release at the time of execution | Installed; evaluate upgrade |
| `gcloud version` | **Google Cloud SDK 591.0.0** | `bq 2.1.41`; `core 2026.10.26`; `gcloud-crc32c 1.0.0`; `gsutil 5.38` | Installed |
| `git --version` | **git version 2.55.0.windows.3** | Windows Git CLI | Installed |

#### B. CLI authentication and configuration

| Command | Output field | Observed result |
| --- | --- | --- |
| `gcloud auth list` | Credentialed accounts | **2** (one active; email addresses omitted) |
| `gcloud config list` | Active configuration | `default` |
| `gcloud config list` | `core.account` | Active account configured (redacted) |
| `gcloud config list` | `core.project` | Pre-existing project selected (redacted) |
| `gcloud config list` | `accessibility.screen_reader` | `False` |
| `gcloud config list` | `core.disable_usage_reporting` | `True` |

#### C. Organization and project inventory

| Command | Item | Observed result |
| --- | --- | --- |
| `gcloud organizations list` | Organization display name | `isaacobaro01-org` |
| `gcloud organizations list` | Organization ID | Redacted in public report |
| `gcloud projects list` | Visible projects | **2** |
| `gcloud projects list` | Project 1 | `My First Project` (project ID and number redacted) |
| `gcloud projects list` | Project 2 | `My First Project` (project ID and number redacted) |
| `gcloud projects list` | Environment column | Blank for both entries |

#### D. Billing account visibility

| Command | Billing account | Reported name | `OPEN` |
| --- | --- | --- | --- |
| `gcloud billing accounts list` | Account 1 (ID redacted) | `My Billing Account` | `False` |
| `gcloud billing accounts list` | Account 2 (ID redacted) | `My Billing Account` | `True` |

**Result interpretation:** The CLI discovers an open billing account; it does **not** prove the active identity can associate new projects with that account. The commands also do not establish available credits, quota capacity, organization-level permissions or Terraform Application Default Credentials.

### Assessment scope and evidence

| Control / check | Command executed | Observation | Assessment |
| --- | --- | --- | --- |
| Terraform CLI | `terraform version` | Terraform **v1.15.8** on **windows_amd64**; CLI reports a newer version available | Installed; upgrade evaluation recommended |
| Google Cloud SDK | `gcloud version` | Google Cloud SDK **591.0.0**; bq 2.1.41, gsutil 5.38 | Installed |
| Git CLI | `git --version` | Git **2.55.0.windows.3** | Installed |
| CLI authentication | `gcloud auth list` | Two credentialed accounts listed; one active | CLI authentication present; identity details retained outside public evidence |
| Active configuration | `gcloud config list` | Default configuration; an existing project selected | Context verified; do not target the existing project for bootstrap without authorization |
| Organization discovery | `gcloud organizations list` | One organization visible: **isaacobaro01-org** | Organization visibility verified; permissions not yet assessed |
| Project discovery | `gcloud projects list` | Two pre-existing projects visible, both named “My First Project” | Inventory baseline established; ownership and billing links unverified |
| Billing discovery | `gcloud billing accounts list` | Two accounts visible: **one OPEN=True, one OPEN=False** | Billing visibility verified; spending authorization and credits unverified |

> **Evidence handling:** This public report intentionally omits personal login names, billing account IDs, full project IDs and detailed IAM membership. Original command output should be retained privately if required for audit. No secrets or access tokens should be committed to GitHub.

### Professional assessment

**Validated**
- The local workstation can invoke Terraform, Google Cloud CLI and Git.
- An active gcloud account and default project configuration exist.
- A GCP organization and two existing projects are discoverable.
- A billing account marked open is discoverable.

**Not yet validated**
- Organization IAM permissions for folder/project creation and organization policy administration.
- Billing-account IAM permissions to associate new projects.
- Project creation quotas, enabled services and API limits.
- Eligibility for free trial credits, active credits, billing budgets and marketplace restrictions.
- Terraform Application Default Credentials (ADC), provider authentication and API authorization.
- Terraform-compatible provider version selection and upgrade impact.
- Policy, audit, remote-state and keyless CI/CD readiness.

### Risks and design considerations

| Risk | Impact | Recommended action |
| --- | --- | --- |
| Existing default project selected | Accidental modifications to unrelated resources | Isolate the bootstrap context and explicitly set project/account in all scripts |
| Billing account visible but not authorized | Project deployment may fail or create unexpected costs | Check billing IAM, current billing status and budget controls before apply |
| Organization discoverable but privileges unknown | Landing-zone folder/project deployment may fail | Assess effective IAM and required roles before writing privileged Terraform |
| Local Terraform upgrade available | Provider/module compatibility or tooling drift | Pin `required_version` and providers; test upgrades through review |
| Credentials and identifiers in raw CLI logs | Unnecessary public disclosure | Publish a redacted summary only; keep original logs private |
| Terraform state not yet established | Risk of losing state or exposing configuration secrets | Design encrypted, access-restricted, versioned GCS backend with locking and recovery procedures |

### Step 0.2 — Organization IAM, Billing and Terraform Authentication Validation

**Evidence date:** 2026-10-31  
**Assessment type:** Organization and billing IAM discovery; local ADC configuration and verification  
**Result:** Organization and billing role assignments verified; local ADC successfully configured and verified. Provisioning permissions, quota and credits remain subject to review.

#### Purpose

This step establishes which organization and billing roles are granted to the bootstrap administrator and prepares local **Application Default Credentials (ADC)** for the Terraform Google provider. `gcloud` CLI authentication and ADC are separate credential mechanisms.

#### Commands used — Windows PowerShell

The following script reproduces the checks. The organization and billing IDs are read from the operator at run time to avoid publishing resource identifiers. Step 4 changes **local workstation credentials**; all other GCP checks are read-only.

```powershell
# ============================================================
# MedCloud 360 - Phase 0, Step 0.2
# IAM, Billing and Terraform Authentication Validation
# Windows PowerShell / VS Code Integrated Terminal
# ============================================================

# 1. Organization IAM - output may reveal administrator identities
$OrgId = Read-Host "Enter GCP organization ID"
gcloud organizations get-iam-policy $OrgId --format=json

# 2. Billing account status and permissions
$BillingId = Read-Host "Enter OPEN billing account ID"
gcloud billing accounts describe $BillingId
gcloud billing accounts get-iam-policy $BillingId --format=json

# 3. Check local Terraform ADC without displaying the token
gcloud auth application-default print-access-token 1>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "ADC authentication successful"
} else {
    Write-Host "ADC not configured"
}

# 4. Configure local ADC (interactive browser sign-in)
gcloud auth application-default login

# 5. Re-test without displaying the token
gcloud auth application-default print-access-token 1>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Terraform ADC verified successfully"
} else {
    Write-Host "Terraform ADC verification failed"
}
```

**Command-output hygiene:** Do not commit the OAuth browser authorization URL, session parameters, credential file contents, tokens, full IAM membership, personal account identifiers, or billing IDs. The ADC file remains on the local workstation outside this repository.

#### Captured results — verification table

| Verification | Observed result | Why it matters | Outcome |
| --- | --- | --- | --- |
| `gcloud organizations get-iam-policy` | Successful response; seven roles assigned to assessed user | Establishes explicit organization-level IAM assignments | **Verified** |
| Organization Administrator | `roles/resourcemanager.organizationAdmin` | Organization governance administration | **Assigned** |
| Project Creator | `roles/resourcemanager.projectCreator` | Project creation capability, subject to effective permissions | **Assigned** |
| Project Mover | `roles/resourcemanager.projectMover` | Project relocation capability, subject to constraints | **Assigned** |
| Service Usage Administrator | `roles/serviceusage.serviceUsageAdmin` | Manage service/API enablement within applicable scope | **Assigned** |
| Billing roles in organization IAM | `roles/billing.admin`, `roles/billing.creator` | Organization-scope billing role assignments observed | **Assigned** |
| Workforce Pool Administrator | `roles/iam.workforcePoolAdmin` | Workforce identity pool management; not equivalent to Workload Identity Federation administration | **Assigned** |
| `gcloud billing accounts describe` | Open billing account; currency **USD**; no parent/master account in response | Establishes billing account status | **Verified open** |
| `gcloud billing accounts get-iam-policy` | `roles/billing.admin` granted on assessed billing account | Establishes direct billing-account administrator assignment | **Verified** |
| Initial ADC check | `Your default credentials were not found` | Local Terraform credential discovery initially failed | **Initial gap identified** |
| `gcloud auth application-default login` | Browser login succeeded; local credentials saved; existing sandbox project registered as quota project | Establishes local ADC | **Configured** |
| Final ADC token test (stdout suppressed) | `Terraform ADC verified successfully` | Confirms ADC can obtain a token without printing it | **Passed** |

**Important quota-project detail:** ADC associated an existing sandbox project for API quota attribution. This does not select the Terraform deployment target or prove sufficient budget. Explicitly configure the bootstrap project and evaluate a dedicated quota project before provisioning.

#### Outcome and next control gates

The assigned organization and billing roles and the successful local ADC verification establish a useful administrative baseline. They do **not** independently establish folder creation rights, service-account/Workload Identity Pool administration, all inherited effective permissions, available credits, budget configuration or project quotas.

**Remaining:** Validate effective bootstrap provisioning rights, resource/API quotas and financial guardrails; approve seed-project and state-backend architecture; then proceed to Phase 0 Step 0.3. For GitHub Actions, use short-lived **Workload Identity Federation** rather than the local ADC user credential.

### Next design checkpoint: Step 0.3 — Terraform Bootstrap Architecture

Prepare a reviewed design for the seed project, protected GCS state bucket, deployment identities, GitHub Actions OIDC and GCP Workload Identity Federation, least-privilege IAM boundaries, pull-request plans and protected applies. Confirm permissions and cost controls before running Terraform provisioning.

### Director-facing summary

The environment-discovery activity established a verified cloud-tooling and resource-visibility baseline for MedCloud 360. The assessment identifies the accessible GCP organization, existing project inventory, and billing-account availability while separating discovery results from deployment authorization. This evidence supports a controlled transition into access validation, cost governance, and secure Terraform bootstrap design.
