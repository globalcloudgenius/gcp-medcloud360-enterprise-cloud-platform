# 06 — Risk and Exception Register

| Control | Value |
| --- | --- |
| Document ID | MC360-RISK-REGISTER |
| Version | 1.0 |
| Owner | MedCloud 360 Engineering |
| Status | Open risk review |
| Last updated | 2026-10-31 |
| Review cadence | At every phase approval and material architecture change |

Risk ratings are **preliminary qualitative assessments**, not measured incident likelihood. No risk is considered closed without validation evidence.

| ID | Risk | Impact | Proposed treatment | State |
| --- | --- | --- | --- | --- |
| R-001 | Bootstrap identity has broad organization roles | High | Use least-privilege deployment identities, WIF and change approvals | Open |
| R-002 | Cloud trial, quota or Marketplace licensing limits deployments | High | Verify billing and quotas; implement budgets before costly workloads | Open |
| R-003 | Unintended changes to pre-existing sandbox project | Medium | Explicit project scoping; isolated Terraform state and review | Open |
| R-004 | Incorrect Palo Alto routing or asymmetric return path | High | Use a supported topology and test both directions and failover | Open |
| R-005 | Proxmox work mistaken for VMware migration experience | Medium | Document a separate vSphere-specific exercise and tooling limitations | Open |
| R-006 | Credentials, personal data or OAuth screenshots published | High | Sanitize before commit; secret scan; check attachments and history | Open |
| R-007 | HA/DR capability inferred from diagrams without tests | High | Define recovery targets and run controlled failure/restore drills | Open |
| R-008 | Security framework mapping misrepresented as formal compliance | High | Use synthetic data; distinguish mapped controls from certified compliance | Open |

## Exception procedure

Record each exception with **ID, owner, affected control, justification, scope, expiry, compensating controls, approval and review date**. An exception does not override a documented data-protection prohibition.

## Governance checkpoint

Before Terraform provisioning, resolve or explicitly accept the design impacts of R-001, R-002 and R-003 with documented test/approval evidence.
