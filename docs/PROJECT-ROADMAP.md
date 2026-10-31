# MedCloud 360 — 12-Phase Engineering Roadmap

| Document control | Value |
| --- | --- |
| Document ID | MC360-DETAIL |
| Version | 1.0 |
| Owner | MedCloud 360 Engineering |
| Status | Design / implementation reference |
| Last updated | 2026-10-31 |
| Review | Per phase gate and material change |


**Document role:** Detailed implementation workstream and acceptance matrix; [03 — Implementation Roadmap](03-IMPLEMENTATION-ROADMAP.md) is the executive summary.

**Objective:** Deliver a secure, automated, GCP-first hybrid cloud platform integrating Azure, on-premises virtualization, Palo Alto inspection, enterprise operations, and analytics.

**Implementation principle:** Establish Terraform, governance, networking and validated inspection **before migration cutover**. Use synthetic healthcare-style data exclusively.

| Phase | Scope | Acceptance criteria |
| --- | --- | --- |
| **0 — Terraform Bootstrap** | Seed project, secured/versioned remote state, IAM, GitHub OIDC federation, reviewed Terraform plans and applies | Repeatable deployment, protected state, keyless automation |
| **1 — GCP Enterprise Landing Zone** | Organization hierarchy, folders/projects, IAM, policies, audit sinks and budgets | Policy, permission and audit tests |
| **2 — GCP Networking** | Prod/nonprod Shared VPC, CIDRs, subnets, firewall policies, DNS, routing and NAT | Allowed/denied traffic and DNS tests |
| **3 — Palo Alto NGFW Security** | Supported VM-Series inspection architecture, zones, policies, App-ID, threat prevention, NAT, routing and logging | Packet-path, policy, return-route and resilience tests |
| **4 — Azure Enterprise Infrastructure** | VNet, VMs, NSGs, private endpoints, Entra/RBAC, Key Vault, Azure Policy, Defender, Monitor and backup | Deployment, access, monitoring and recovery tests |
| **5 — Hybrid Connectivity** | Proxmox edge, GCP HA VPN/Cloud Router/BGP design, Azure VPN integration, hybrid DNS and routing | Connectivity, BGP/VPN, DNS/MTU and failure tests |
| **6 — Cloud Workload Foundation** | Hardened GCE, regional MIG, ALB with Cloud Armor, private Cloud SQL HA, backups, IaaS/PaaS/SaaS support models | Application, scaling, security and restore tests |
| **7 — VMware / Proxmox Migration** | Inventory, dependency mapping, migration waves, Proxmox test migration and VMware-specific workflow, cutover/rollback | Migration, recovery and VMware workflow evidence |
| **8 — Security & Vulnerability Operations** | SCC, optional CNAPP evaluation, patching, configuration risks and remediation; HIPAA/NIST/CIS control mapping | Finding → remediation → retest records |
| **9 — Enterprise Operations & Automation** | Observability, SLOs, troubleshooting, incident response, DR, Terraform drift and FinOps; cross-team handoffs | Incident reports, alerts, DR and cost evidence |
| **10 — Analytics & AI Infrastructure** | Synthetic BigQuery pipeline, access control, audit logging, reporting and controlled AI PoC | Data pipeline, access and AI security tests |
| **11 — Final Validation & Documentation** | Architecture diagrams, runbooks, risk and requirements matrix, technical handover | Requirements-to-evidence traceability |

## Architecture and delivery standards

- **IaC and change control:** Terraform-managed resources, isolated state, review and approved deployment.
- **Security:** Least-privilege IAM, native cloud protections, centralized logs and Palo Alto inspection for **explicitly routed** paths.
- **Network correctness:** Shared VPC attachments are administrative relationships, not packet-inspection hops; verify symmetric routing.
- **Reliability:** Multi-zone design where appropriate, measured recovery objectives, backups and DR testing.
- **Operations:** Monitor, troubleshoot, remediate vulnerabilities, manage costs, and document security/network/identity/data team handoffs.
- **Healthcare safeguards:** Synthetic data only, documented relevant controls, no claims of certified compliance.
- **Budget discipline:** Validate quotas, cloud charges and Palo Alto licensing before deployment.

## Engineering records

- [Phase 0 — Workstation discovery, IAM, billing and ADC validation](00-terraform-bootstrap/README.md)
- [Authentication evidence record](00-terraform-bootstrap/evidence/PH0-STEP02-ADC-001.md)

**Repository organization:** Implementation files will be maintained under `terraform/`, `diagrams/`, `paloalto/`, `scripts/`, `tests/` and phase-specific `docs/` folders as resources are introduced.
