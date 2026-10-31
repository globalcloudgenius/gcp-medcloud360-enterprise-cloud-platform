# Phase 0 — IAM Roles and Permissions Matrix

| Document control | Value |
| --- | --- |
| ID / Version | MC360-PH0-IAM-001 / 1.0 |
| Owner | MedCloud 360 Engineering |
| Status | Required roles proposed; only marked assignments verified |
| Updated | 2026-10-31 |
| Scope | GCP bootstrap (Steps 0.3–0.7); least-privilege design |

## Access model

**Human administrator:** limited initial project/billing/state setup using local ADC. **CI deployer:** dedicated service account impersonated by GitHub Actions through restricted Workload Identity Federation (WIF); no static JSON keys. **Runtime identities:** distinct from provisioning identities. Apply roles at the **smallest practical resource scope**, not organization-wide by default.

## Role and permission requirements

| Activity / resource scope | Typical IAM role or precise permission | Status / guidance |
| --- | --- | --- |
| Create bootstrap project (organization or folder) | `roles/resourcemanager.projectCreator` → `resourcemanager.projects.create` | **Verified direct assignment** at organization; effective quotas/policies still pending |
| Associate project with billing account | `roles/billing.user` on billing account (or equivalent `billing.resourceAssociations.create`); `roles/billing.projectManager` on target project (or equivalent project billing-assignment permission) | **Not end-to-end tested**; direct `roles/billing.admin` on open account **verified** |
| Enable required GCP APIs (bootstrap project) | `roles/serviceusage.serviceUsageAdmin` → `serviceusage.services.enable` | **Verified direct assignment** at organization; API constraints untested |
| Create/configure GCS Terraform state bucket (bootstrap project) | Temporary `roles/storage.admin` or minimal custom role including `storage.buckets.create` and bucket configuration permissions | **Not verified**; grant only for bootstrap, then reduce scope |
| Read/write/lock GCS Terraform state (state bucket) | `roles/storage.objectAdmin` at bucket scope, if required by selected backend operations; avoid bucket-admin role for ordinary CI | **Planned**; verify backend operations, object versioning and recovery |
| Create/manage Terraform service accounts (bootstrap project) | `roles/iam.serviceAccountAdmin` | **Not verified**; restricted to setup administrator |
| Create GitHub WIF pool/provider (bootstrap project) | `roles/iam.workloadIdentityPoolAdmin` | **Not verified**; distinct from existing `roles/iam.workforcePoolAdmin` |
| Permit GitHub federated identity to impersonate deployer (target service account) | `roles/iam.workloadIdentityUser` binding for tightly scoped WIF principal/principalSet | **Planned**; constrain pool provider attributes, repo identity and approved contexts |
| Modify service account IAM policy | `roles/iam.serviceAccountAdmin` or minimum `iam.serviceAccounts.setIamPolicy` on target SA | **Not verified**; limit to identity administrator |
| Deploy governed resources (later project(s)) | Service-specific roles or custom role containing only approved resource create/update/read permissions; `roles/iam.serviceAccountUser` only where attachment is required | **Future design**, not automatic grants |
| Manage organization policy exceptions (only if necessary) | `roles/orgpolicy.policyAdmin` on relevant parent; explicit approval | **Not verified; not a default bootstrap grant** |
| Configure budget alerts / inspect costs | Billing-account budget management permissions, e.g. `roles/billing.admin` where sufficient; validate budget API privileges | **Not verified end-to-end**; budget notifications do not cap spending |
| Review audit events | Narrow logging viewer permissions (and `roles/logging.privateLogViewer` only for restricted logs when needed) | **Planned**, grant only to authorized reviewers |

## Confirmed observations (read-only PowerShell)

| Evidence | Result |
| --- | --- |
| Organization Project Creator | Direct assignment **True** |
| Organization Billing Admin | Direct assignment **True** |
| Organization Service Usage Admin | Direct assignment **True** |
| Open USD billing account Billing Admin | Direct assignment **True** |
| Two existing projects | **ACTIVE**; neither is the proposed bootstrap project |
| Local ADC token retrieval | **PASS** |
| Proposed `medcloud360-prj-bootstrap` | **Not created / availability unchecked** |
| Project quota, restrictive policies and project billing attachment | **Not yet verified** |

Additional organization roles observed in prior IAM review include organization administrator, project mover, billing creator and **Workforce** Pool Admin. These are **not** a recommendation to assign them to CI and do **not** establish Workload Identity Pool Admin access.

## Read-only role inspection (PowerShell)

```powershell
# Do not paste raw IAM policies or account identifiers into public GitHub.
$OrgId = "<ORG_ID>"
$Account = gcloud config get-value account 2>$null
$Policy = gcloud organizations get-iam-policy $OrgId --format=json |
    ConvertFrom-Json
$RoleNames = @(
  "roles/resourcemanager.projectCreator",
  "roles/serviceusage.serviceUsageAdmin",
  "roles/iam.workloadIdentityPoolAdmin",
  "roles/iam.serviceAccountAdmin"
)
$RoleNames | ForEach-Object {
  $role = $_
  [PSCustomObject]@{
    Role = $role
    DirectAssignment = [bool]@($Policy.bindings | Where-Object {
      $_.role -eq $role -and $_.members -contains "user:$Account"
    }).Count
  }
}
```

**Limit:** A direct-binding check cannot establish effective permissions through groups, conditional IAM, deny policies, inherited grants or quota; validate those separately. Do not run broad `add-iam-policy-binding` commands without an approved deployment design.

## Approval criteria

- [ ] Confirm bootstrap project parent, creation limits, and billing association.
- [ ] Confirm temporary project/bucket administrator rights, then remove excessive grants.
- [ ] Define and approve deployer service account permissions and bucket-scoped state access.
- [ ] Restrict WIF to the correct GitHub repository and deployment context.
- [ ] Test authorized and denied access; record sanitized evidence before declaring completion.

**References:** [Google Cloud project IAM](https://docs.cloud.google.com/resource-manager/docs/access-control-proj) · [Project billing permissions](https://docs.cloud.google.com/resource-manager/docs/assign-iam-roles) · [GCS Terraform state](https://docs.cloud.google.com/docs/terraform/resource-management/store-state) · [Workload Identity Federation](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-other-providers)

**Related:** [Step 0.3](STEP-03-BOOTSTRAP-ARCHITECTURE.md) · [Step 0.4](STEP-04-BOOTSTRAP-DEPLOYMENT.md)
