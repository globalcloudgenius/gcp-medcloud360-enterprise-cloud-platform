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

### Follow-up actions: Step 0.2 — Authorization, Billing and Authentication Validation

Perform the following **read-only** checks using approved administrator access:

```powershell
# Organization IAM: review privately; output can contain sensitive identities
gcloud organizations get-iam-policy 246298189177 --format=json

# Open billing account status and IAM: do not publish the account ID or membership
gcloud billing accounts describe BILLING_ACCOUNT_ID
gcloud billing accounts get-iam-policy BILLING_ACCOUNT_ID --format=json

# Terraform ADC presence; never print an access token to a shared terminal/log
gcloud auth application-default print-access-token 1>$null
```

Also verify available billing credits and applicable quotas using authorized billing views and project/quota tools. Where `get-iam-policy` omits inherited access, use appropriate effective-access or policy troubleshooting checks rather than assuming permissions are absent.

**Step 0.2 exit criteria:** Explicitly establish which identity can create projects/folders, which principal can link billing, what quotas and spending controls apply, and which ADC identity Terraform will use.

### Next design checkpoint: Step 0.3 — Terraform Bootstrap Architecture

Prepare a reviewed design for the seed project, protected GCS state bucket, deployment identities, GitHub Actions OIDC and GCP Workload Identity Federation, least-privilege IAM boundaries, pull-request plans and protected applies. Confirm permissions and cost controls before running Terraform provisioning.

### Director-facing summary

The environment-discovery activity established a verified cloud-tooling and resource-visibility baseline for MedCloud 360. The assessment identifies the accessible GCP organization, existing project inventory, and billing-account availability while separating discovery results from deployment authorization. This evidence supports a controlled transition into access validation, cost governance, and secure Terraform bootstrap design.
