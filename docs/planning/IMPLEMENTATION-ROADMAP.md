# 03 — Implementation Roadmap

| Document control | Value |
| --- | --- |
| Document ID | MC360-03 |
| Version | 1.0 |
| Owner | MedCloud 360 Engineering |
| Status | Design / implementation reference |
| Last updated | 2026-10-31 |
| Review | Per phase gate and material change |


**Sequence:** Bootstrap → Landing Zone → Network → Palo Alto → Azure → Hybrid → Workloads → Migration → Security & Operations → Analytics → Validation.

| Phase | Engineering scope | Exit evidence |
| --- | --- | --- |
| **0 — Terraform Bootstrap** | Seed project, protected state, IAM, GitHub Actions and federation | Successful controlled plan/apply; state and identity tests |
| **1 — GCP Enterprise Landing Zone** | Organization hierarchy, projects, policies, logging, budgets | IAM, governance and audit validations |
| **2 — GCP Networking** | Prod/nonprod Shared VPC, DNS, routing, firewall policies | Route, DNS and allow/deny traffic tests |
| **3 — Palo Alto Security** | VM-Series, zones, NAT, App-ID, threat prevention, logging, inspection routing | Packet-path and firewall resilience evidence |
| **4 — Azure Infrastructure** | VNet, VMs, Entra, policy, Defender, monitoring and backup | Deployment, security and recovery tests |
| **5 — Hybrid Connectivity** | Proxmox edge, GCP HA VPN/BGP, Azure VPN and DNS | Connectivity, route and tunnel-failure tests |
| **6 — Cloud Workload Foundation** | GCE, regional MIG, ALB/Cloud Armor, private Cloud SQL | Application, scaling and restore tests |
| **7 — Migration** | Proxmox test migration plus VMware-specific workflow, cutover and rollback | Migration and rollback reports |
| **8 — Security Operations** | SCC, vulnerability findings and remediation | Finding-to-remediation trace |
| **9 — Enterprise Operations** | Observability, incidents, DR, troubleshooting and FinOps | Runbooks, drills, cost reports |
| **10 — Analytics and AI** | Synthetic BigQuery pipeline and controlled AI PoC | Data-access and functional tests |
| **11 — Final Validation** | Requirements mapping, diagrams and handover | Approved acceptance evidence |

**Delivery rule:** Finish the landing-zone, network and firewall acceptance gates before workload cutover. Start migration discovery in parallel.

This numbered document is the **executive phase summary**. See [the detailed technical implementation and acceptance matrix](DETAILED-ROADMAP.md) and [Phase 0 technical records](../00-terraform-bootstrap/README.md).
