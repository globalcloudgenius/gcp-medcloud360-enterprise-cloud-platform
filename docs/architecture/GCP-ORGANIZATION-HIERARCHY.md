# MedCloud360 — GCP Organization and Project Hierarchy

**Implementation status:** Organization hierarchy deployed and Terraform-managed as of November 4, 2026.  
**GCP organization ID:** `246298189177`

```text
GCP Organization: 246298189177
│
├── Bootstrap
│   └── mc360-prj-bootstrap
│       └── GCS Terraform Remote State ✓
│
├── Platform
│   ├── mc360-prj-network
│   └── mc360-prj-observability
│
├── Security
│   ├── mc360-prj-security
│   └── mc360-prj-kms
│
├── Production
│   ├── mc360-prj-prod-app
│   └── mc360-prj-prod-data
│
├── Nonproduction
│   ├── mc360-prj-dev
│   └── mc360-prj-test
│
└── Sandbox
    └── mc360-prj-lab
```

## Terraform foundation

- **Six organization folders and ten GCP projects** are represented in Terraform state.
- **Terraform state backend:** Google Cloud Storage bucket `mc360-bootstrap-tfstate-970590923874` in `mc360-prj-bootstrap`.
- **State prefix:** `foundation/terraform/state`.
- **Backend migration:** Completed successfully from the temporary test-project bucket using `terraform init -migrate-state`.
- **Bucket protections verified:** Public access prevention enforced; uniform bucket-level access; object versioning; seven-day soft delete; regional `us-central1` storage.
- **Most recent plan:** `0 to add, 8 to change, 0 to destroy`; the eight proposed in-place updates are pending billing associations.

## Governance and next steps

Existing organization constraints were verified as effectively enforced for service-account key creation/upload restrictions, prevention of default service-account automatic IAM grants, uniform bucket-level access, and zonal DNS defaults. Protocol forwarding is limited to `INTERNAL`.

**In progress:** Complete billing associations for the eight remaining projects, review IAM least privilege, and configure a keyless Terraform deployment identity. Networking, monitoring, hybrid connectivity, and healthcare-specific compliance controls require further implementation and validation.

> This is an independent engineering portfolio lab, not an official Vitalant environment. Do not commit Terraform state, `.tfvars` with secrets, credential files, or real patient data. The architecture does not by itself establish HIPAA compliance.
