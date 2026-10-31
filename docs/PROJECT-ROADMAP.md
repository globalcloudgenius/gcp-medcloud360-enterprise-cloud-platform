# MedCloud 360 — 12-Phase Implementation Roadmap

**Mission:** Design and implement a secure, governed, resilient GCP-first hybrid cloud platform spanning Google Cloud, Microsoft Azure and an on-premises virtualization lab, with automated delivery and verifiable engineering outcomes.

**Build principle:** Establish Terraform bootstrap, landing zone, network segmentation, and validated inspection before migrating workloads. Begin workload assessment in parallel. Use synthetic healthcare-like data exclusively.

| Phase | Implementation | Engineering activities | Acceptance evidence |
|---|---|---|---|
| **0** | **Terraform Bootstrap** | Verify organization, billing and bootstrap privileges; enable foundational APIs; create seed project, versioned/restricted state storage, deployment identity and federated GitHub Actions workflows with approval gates. | Approved Terraform plan/apply; protected state; short-lived identity; repeatability test. |
| **1** | **GCP Enterprise Landing Zone** | Establish platform/workload folders and projects; organization policies, least-privilege IAM, audit sinks, budget alerts, labels, policy exceptions and documentation. | IAM permission tests, policy enforcement, audit logs and budget controls. |
| **2** | **GCP Networking** | Plan CIDRs; production and nonproduction Shared VPC host/service projects; subnets, private DNS, firewall policies, appropriate NAT, egress and routes. | Allowed/denied flow matrix, DNS and connectivity test reports. |
| **3** | **Palo Alto NGFW Security** | Choose supported VM-Series design; management isolation; NIC/zone and virtual router configuration; App-ID, Threat Prevention, NAT, log forwarding; applicable internal passthrough load balancing and policy-based/route steering. | Traced designated inspection flows, symmetric return paths, rule logs, health checks and fault testing. |
| **4** | **Azure Enterprise Infrastructure** | Implement Azure networking, VMs, NSGs, private endpoints, Entra/RBAC, Key Vault, Azure Policy, Defender for Cloud, Monitor and recovery services using IaC. | Azure deployment, access, security, monitoring and backup/recovery tests. |
| **5** | **Hybrid Connectivity** | Build on-premises Proxmox network and edge; design GCP HA VPN/Cloud Router/BGP where supported and financially appropriate; integrate Azure connectivity, DNS and route advertisement. | Routed connectivity checks, BGP/tunnel tests, DNS/MTU troubleshooting and denied-flow verification. |
| **6** | **Cloud Workload Foundation** | Create hardened GCE instances, regional multi-zone managed instance group, health checks, external Application Load Balancer with attached Cloud Armor policies, private Cloud SQL HA/PITR, Secret Manager, backup and synthetic workloads. Cover IaaS, PaaS and SaaS support models. | Application functionality, autoscale/failover, IAM, database restore and security checks. |
| **7** | **VMware / Proxmox Migration** | Inventory and dependency analysis, migration wave plan, hands-on Proxmox VM move/rebuild/import, test cutover and rollback; document and, if feasible, exercise VMware vSphere-specific migration tools and procedures. | Migration report with RTO/RPO observations, rollback evidence and VMware-specific workflow record. |
| **8** | **Security & Vulnerability Operations** | Security Command Center, optional Wiz-like CNAPP comparison, VM vulnerability/patch processes, configuration assessment, risk prioritization and Terraform-based remediation. Map relevant HIPAA/NIST/CIS safeguards. | Tracked findings, change approvals, remediation retests, audit and incident records. |
| **9** | **Enterprise Operations & Automation** | Establish Cloud Monitoring/Azure Monitor, dashboards, SLOs, runbooks, incident response, network/identity/performance troubleshooting, DR exercises, IaC drift detection, budget and FinOps reports. Define cross-team handoffs. | Incident root-cause reports, tested alerts, DR results, cost reports and change records. |
| **10** | **Analytics & AI Infrastructure** | Synthetic-data BigQuery pipeline, dataset authorization, logging/retention, reporting and bounded AI infrastructure proof of concept. | Repeatable data workflow, security access tests, dashboard and AI cost/security assessment. |
| **11** | **Final Validation & Documentation** | Consolidate diagrams, design decisions, technical runbooks, security controls, architecture-to-implementation traceability, failover and recovery evidence and director-level summary. | Requirements-to-evidence matrix, reviewed deliverables, limitations and handover materials. |

## Enterprise design standards

- **IaC-first:** All applicable cloud resources managed by version-controlled Terraform modules, approved plans and isolated state.
- **Least privilege and defense in depth:** IAM, organization policy, secure service identities, network firewall rules, Palo Alto inspection for selected routed paths and centralized logs.
- **Networking correctness:** Distinguish GCP folder/project relationships from packet flow. Shared VPC association is not a firewall hop. Verify appliance steering and return-path symmetry; avoid assuming all east-west traffic traverses Palo Alto.
- **Reliability:** Region/zone design, documented RTO/RPO targets, health checks, backups, recovery tests and failure-domain analysis.
- **Security governance:** Synthetic data, auditable change control, vulnerability findings and remediation evidence; no claims of HIPAA certification from architecture alone.
- **Operational discipline:** Monitor, alert, troubleshoot, document root cause, optimize cost, and record dependencies with security/network/identity/data specialist teams.
- **Cost constraints:** Assess marketplace licensing and GCP trial limitations before deploying Palo Alto VM-Series or expensive managed services.

## Recommended repository documentation paths

```text
docs/
  PROJECT-ROADMAP.md
  00-terraform-bootstrap/
  01-gcp-landing-zone/
  02-gcp-networking/
  03-paloalto-security/
  04-azure-infrastructure/
  05-hybrid-connectivity/
  06-cloud-workloads/
  07-workload-migration/
  08-security-operations/
  09-enterprise-operations/
  10-analytics-ai/
  11-validation-evidence/
terraform/
  bootstrap/
  gcp/
  azure/
  modules/
diagrams/
paloalto/
scripts/
tests/
```

Directories are created as their first tracked files are committed; Git does not track empty directories.
