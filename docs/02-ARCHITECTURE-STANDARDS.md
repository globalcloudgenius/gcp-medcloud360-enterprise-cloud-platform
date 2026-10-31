# 02 — Enterprise Architecture and Engineering Standards

## Architectural principles

| Standard | Engineering expectation |
| --- | --- |
| Secure by design | Least privilege, defense in depth, encryption and audited access |
| Infrastructure as Code | Terraform modules, version pinning, isolated remote state and reviewed changes |
| Environment separation | Independent production/nonproduction projects, identity boundaries and Shared VPC associations |
| Hybrid networking | Document CIDRs, trust boundaries, DNS, route exchange and failure paths |
| Inspection correctness | Use supported VM-Series topology; verify designated traffic actually traverses firewalls and returns symmetrically |
| Reliability | Define RTO/RPO, failure domains, backup, restore and failover criteria |
| Observability | Centralized logs, metrics, alerts, incident escalation and actionable runbooks |
| Financial governance | Budgets, cost allocation, licensing checks and deliberate teardown of lab resources |
| Sensitive-data controls | Synthetic healthcare data; no PHI/PII, credentials or Terraform state in public GitHub |

## Target architecture domains

1. **Control plane:** Organization, IAM, folders, projects, policy and Terraform/GitHub Actions using short-lived federation.
2. **Network plane:** Production and nonproduction Shared VPCs, subnets, firewall policies, Cloud DNS, NAT, HA VPN and Cloud Router/BGP where applicable.
3. **Security inspection:** Palo Alto VM-Series for explicitly steered traffic, native GCP controls, vulnerability management and SIEM forwarding.
4. **Cloud workloads:** Hardened Compute Engine, regional MIG, external Application Load Balancer with Cloud Armor backend policy, private Cloud SQL HA and BigQuery.
5. **Hybrid and migration:** Azure platform, Proxmox lab and separate VMware-specific migration design/testing.
6. **Operations:** Monitoring, incident management, backup/DR, root-cause analysis, cost and service optimization.

## Change and validation gates

**Design → peer review → Terraform validate/plan → security checks → approval → apply → functional and security verification → evidence capture → rollback readiness.**

Keep architecture diagrams distinct for **resource hierarchy**, **actual packet flow**, and **deployment pipeline**. Shared VPC attachment is not packet traversal. Palo Alto inspection is not assumed for every flow.

## Identity and secrets

Local ADC supports controlled workstation bootstrap. GitHub Actions must use Workload Identity Federation with narrowly scoped service accounts. Never commit tokens, JSON keys, personal authentication screenshots, VPN shared secrets, sensitive IAM exports or cloud-state files.

## Evidence requirements

Record command/version, time, expected outcome, observed result, deviations and follow-up owner. Store sanitized evidence in phase-specific directories and link it from [04 — Engineering Evidence](04-ENGINEERING-EVIDENCE.md).
