# 05 — Architecture Decision Register

| Control | Value |
| --- | --- |
| Document ID | MC360-ADR-REGISTER |
| Version | 1.0 |
| Owner | MedCloud 360 Engineering |
| Status | Proposed decisions — pending design validation |
| Last updated | 2026-10-31 |
| Review gate | Before Phase 0.3 design approval and relevant phase implementation |

Architecture decisions document **context, options, decision, rationale, consequences, and validation**. Entries below are proposed design directions, not evidence that resources exist.

| ID | Decision under review | Rationale | Required validation |
| --- | --- | --- | --- |
| ADR-001 | GCP-first enterprise landing zone with separate platform and workload scopes | Governance and production/nonproduction separation | Folder/project IAM, billing and org policy feasibility |
| ADR-002 | Terraform remote GCS state and GitHub Actions with Workload Identity Federation | Auditable, repeatable and keyless deployments | Bootstrap privileges, state isolation, approvals and recovery |
| ADR-003 | Prod/nonprod Shared VPC host/service-project model | Centralized network governance with workload isolation | Subnet-level IAM, routing, firewall policies and DNS |
| ADR-004 | Palo Alto VM-Series for selected inspection paths | Demonstrate NGFW policy, threat inspection and logging | Supported Google Cloud topology, symmetrical routes, health and licensing |
| ADR-005 | Proxmox lab plus separate VMware-specific migration workflow | Practical lab migration with explicit VMware coverage | VMware tooling feasibility, cutover and rollback evidence |
| ADR-006 | Synthetic healthcare data in Cloud SQL/BigQuery and controlled AI | Demonstrate sensitive-data architecture without handling PHI | Access controls, logging, costs and retention |

## ADR workflow

1. Create a dedicated `docs/adr/ADR-NNN-short-title.md` when an option is selected for implementation.
2. Record problem statement, alternatives, decision authority, trade-offs, cost and security implications.
3. Confirm the decision against vendor support constraints and test evidence.
4. Mark **Proposed → Accepted → Superseded** as appropriate; never silently rewrite an approved decision.

**Next action:** Formalize ADR-001 and ADR-002 in Phase 0.3 before bootstrap provisioning.
