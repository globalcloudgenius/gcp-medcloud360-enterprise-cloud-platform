# 01 — Project Charter

| Document control | Value |
| --- | --- |
| Document ID | MC360-01 |
| Version | 1.0 |
| Owner | MedCloud 360 Engineering |
| Status | Design / implementation reference |
| Last updated | 2026-10-31 |
| Review | Per phase gate and material change |


**Project:** MedCloud 360 — Enterprise GCP-First Hybrid Cloud Platform  
**Purpose:** Deliver an enterprise-style cloud engineering reference platform for secure healthcare-like workloads using synthetic data.

## Business objective

Establish a governed, repeatable foundation for GCP infrastructure integrated with Azure and on-premises virtualization. Demonstrate cloud modernization, layered security, resilience, operational support, analytics and cost governance.

## Scope

**In scope:** Terraform/GitHub Actions bootstrap; GCP enterprise landing zone and Shared VPC; Palo Alto VM-Series inspected paths; Azure networking, identity and workloads; hybrid connectivity; VMware/Proxmox migration workflows; GCP HA application/data platform; vulnerability response; monitoring, FinOps, BigQuery and controlled AI.

**Outside scope:** Real patient data, operating an official Vitalant environment, production HIPAA certification or claims about employer infrastructure.

## Outcomes and measures

| Outcome | Measure |
| --- | --- |
| Repeatable cloud foundation | Reproducible Terraform deployment and documented state recovery |
| Governed environments | Least-privilege IAM and organization-policy tests |
| Secure hybrid networking | Permitted/denied flow tests, routing and inspection traces |
| Resilient workloads | Health-check, restore, failover and migration rollback evidence |
| Operational readiness | Alerting, vulnerability remediation and incident runbooks |
| Cost accountability | Budgets, tagging and resource cost review |

## Delivery governance

Work follows [the 12-phase implementation roadmap](03-IMPLEMENTATION-ROADMAP.md) with change review, acceptance gates and evidence links. Architecture decisions and exceptions must be documented before applying changes. Each phase is signed off against its test evidence rather than assumed complete.

**Classification:** Independent public portfolio project. Use synthetic data only.

## Accountability and decision management

The [Architecture Decision Register](05-ARCHITECTURE-DECISIONS.md) records technical trade-offs; the [Risk and Exception Register](06-RISK-REGISTER.md) tracks unresolved exposure and approval gates. Evidence is linked through [04 — Engineering Evidence](04-ENGINEERING-EVIDENCE.md).
