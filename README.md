# MedCloud 360
### Enterprise GCP-First Hybrid Cloud Platform Engineering & Security Modernization

**Technologies:** Google Cloud Platform · Microsoft Azure · Terraform · Palo Alto VM-Series · VMware / Proxmox · Cloud Security · Analytics & AI

## Project overview

**MedCloud 360** is an independent cloud engineering reference project focused on building and operating secure, resilient, mission-critical infrastructure in a healthcare-style environment. It combines a Terraform-managed GCP landing zone, Azure infrastructure, Palo Alto inspection, hybrid connectivity, workload migration, security operations, and analytics using **synthetic data only**.

## Goals and expected outcomes

- **Governed foundation:** GCP resource hierarchy, least-privilege IAM, policies, audit logging and cost controls.
- **Automated delivery:** Secure Terraform state, GitHub Actions, federated authentication and change approvals.
- **Secure hybrid networking:** Shared VPC, DNS, VPN/BGP, Palo Alto VM-Series inspection and Azure integration.
- **Modernized workloads:** Highly available applications, private databases, VMware/Proxmox migration and recovery.
- **Operational excellence:** Vulnerability remediation, monitoring, troubleshooting, incident response and FinOps.
- **Data innovation:** Secure BigQuery analytics and a controlled AI proof of concept.

## 12-phase roadmap

| Phase | Workstream | Target outcome |
| --- | --- | --- |
| **0** | Terraform Bootstrap | Secure state, deployment identities and CI/CD |
| **1** | GCP Enterprise Landing Zone | Resource hierarchy, IAM and governance |
| **2** | GCP Networking | Shared VPC, routing, DNS and segmentation |
| **3** | Palo Alto NGFW Security | Inspected traffic, policy enforcement and resilience |
| **4** | Azure Enterprise Infrastructure | Compute, networking, identity and security |
| **5** | Hybrid Connectivity | On-premises, GCP and Azure integration |
| **6** | Cloud Workload Foundation | HA compute, load balancing and Cloud SQL |
| **7** | VMware / Proxmox Migration | Assessment, cutover and rollback |
| **8** | Security & Vulnerability Operations | Security findings and remediation |
| **9** | Enterprise Operations & Automation | Monitoring, troubleshooting, DR and FinOps |
| **10** | Analytics & AI Infrastructure | Protected BigQuery and AI workloads |
| **11** | Final Validation & Documentation | Acceptance tests, runbooks and handover |

**Delivery sequence:** Bootstrap → Landing zone → Networking → Palo Alto → Azure & hybrid connectivity → Workloads → Migration → Operations → Analytics → Validation.

## Enterprise documentation

| Document | Purpose |
| --- | --- |
| [01 — Project Charter](docs/01-PROJECT-CHARTER.md) | Executive goals, business outcomes and scope |
| [02 — Architecture Standards](docs/02-ARCHITECTURE-STANDARDS.md) | Security, networking, IaC and engineering controls |
| [03 — Implementation Roadmap](docs/03-IMPLEMENTATION-ROADMAP.md) | Twelve phases and acceptance gates |
| [04 — Engineering Evidence](docs/04-ENGINEERING-EVIDENCE.md) | Test records, command results and traceability |

Additional governance: [05 — Architecture Decisions](docs/05-ARCHITECTURE-DECISIONS.md) · [06 — Risk & Exceptions](docs/06-RISK-REGISTER.md)

**Roadmap convention:** [03 — Implementation Roadmap](docs/03-IMPLEMENTATION-ROADMAP.md) is the concise executive summary; [Detailed Engineering Roadmap](docs/PROJECT-ROADMAP.md) contains technical acceptance criteria.

## Supporting engineering records

- [Engineering roadmap and acceptance criteria](docs/PROJECT-ROADMAP.md)
- [Phase 0 — Terraform Bootstrap: assessment and commands](docs/00-terraform-bootstrap/README.md)
- [ADC authentication evidence](docs/00-terraform-bootstrap/evidence/PH0-STEP02-ADC-001.md)

## Delivery standards

Infrastructure is defined through reviewed Terraform changes and validated through access, connectivity, security, migration, recovery and operational tests. This is an **independent portfolio reference project**, not an official Vitalant environment. Use synthetic data only; do not commit credentials, Terraform state, private keys, VPN secrets or protected information. Security control mapping does not itself establish HIPAA compliance.
