# MedCloud 360 · CareNotes
### Secure hybrid-compute healthcare platform on Google Cloud, built entirely in Terraform

**Stack:** Google Cloud · Terraform · GitHub Actions (Workload Identity Federation) · Cloud Run · Compute Engine · VPC Service Controls · Security Command Center · BigQuery · Vertex AI (Gemini)

MedCloud 360 is an independent portfolio project: a governed, zero-trust Google Cloud platform for a fictional healthcare provider, with a working application — **CareNotes** — that exercises every control. All patient data is **synthetic**.

```
Clinician ─► Global HTTPS LB ─► Cloud Armor ─► IAP ─► Cloud Run portal (us-central1 + us-east4)
                                                          │ upload (CMEK)
                                                          ▼
         GCS phi-intake ─► Pub/Sub ─► processor ─► DLP (find + redact PHI) ─► Gemini (de-identified only) ─► BigQuery
Hospital ─► MLLP/TLS :2575 ─► internal TCP LB ─► HL7 gateway MIG (3 zones) ─► Pub/Sub ─► BigQuery
All audit logs ─► 7-year GCS + BigQuery SIEM ─► detections ─► alerts        SCC findings ─► scc-router ─► alert / auto-fix
                    └── everything holding PHI sits inside a VPC Service Controls perimeter ──┘
```

## What it demonstrates

| Area | Built here |
|---|---|
| Governance | 14 organization policies at the root (domain-restricted sharing applied last), custom Secure Boot constraint on prod, sandbox exception, resource tags, budgets |
| Identity | Keyless CI (Workload Identity Federation), per-workload service accounts, no SA keys anywhere, IAP for every human path |
| Hub-and-spoke network | 4 VPCs in a Shared VPC host, **NCC STAR topology** (prod and nonprod can never route to each other), network firewall policies with secure tags, org firewall baseline, restricted Google APIs VIP, Cloud DNS, NAT, optional HA VPN + BGP lab |
| IaaS | HL7 v2 MLLP/TLS interface engine on a regional MIG (raw TCP — the one thing Cloud Run cannot do), internal passthrough LB, Shielded VM, CMEK disks |
| VM patching & vulnerabilities | VM Manager zone-by-zone patch deployment with drain/verify hooks, OS policies, OS inventory and CVE reports, snapshots, immutable MIG rollouts |
| PaaS / serverless | Cloud Run in 2 regions behind a global LB with outlier-detection failover, Pub/Sub push, Cloud Run jobs, Cloud Scheduler |
| PHI protection | Cloud KMS CMEK (enforced on prod by org policy), Sensitive Data Protection, VPC Service Controls (dry run → enforced), Data Access audit logs, TLS for HL7 |
| Security operations | Security Command Center notifications → router → alert + auto-remediation, findings in BigQuery, mute rule with accepted-risk owner, seed-and-fix lab |
| Detection | Org-wide audit sinks (7-year GCS + BigQuery SIEM), log-based detections (IAM, org policy, firewall, SA keys, VPC-SC violations), alerting |
| Reliability | SLO with burn-rate alerts, multi-region portal, zone-redundant MIG, dead-letter queue, DR runbook with RTO/RPO, chaos switch |
| Analytics & AI | HL7 → BigQuery with no code (BigQuery subscription), daily de-identified exports, Gemini summaries of de-identified notes |
| Automation | 9 staged Terraform stacks with separate state, PR plans, approval-gated applies, Checkov/tflint/Trivy/gitleaks, nightly drift detection |

The **Platform Proof** page in the app runs 12 live checks — it deliberately tries forbidden actions (create a key, make a bucket public, write without CMEK, copy PHI out of the perimeter) and passes only when Google Cloud refuses them.

## Deploy

```bash
./scripts/discover.sh      # reads your org, writes config/mc360.tfvars (git-ignored)
./scripts/deploy-all.sh    # stages 00 -> 08, builds and deploys the app
./scripts/enforce-guardrails.sh   # after reviewing dry-run results: CMEK + VPC-SC enforced
```

Full guide: [docs/carenotes/DEPLOYMENT.md](docs/carenotes/DEPLOYMENT.md). Runs on the free trial (Windows VM and GPUs are coded but off).

## Repository map

| Path | Contents |
|---|---|
| [`terraform/00-bootstrap`](terraform/00-bootstrap) … [`08-observability`](terraform/08-observability) | One stack and one state per stage; `_common/` is copied into each by `scripts/sync-common.sh` |
| [`app/carenotes`](app/carenotes) | Portal, processor, scc-router, jobs (one image, five entrypoints) |
| [`app/hl7-gateway`](app/hl7-gateway) | MLLP/TLS gateway and VM bootstrap |
| [`app/tests`](app/tests) | Offline tests incl. a real MLLP/TLS round trip |
| [`scripts/`](scripts) | `discover`, `deploy-all`, `deploy-app`, `enforce-guardrails`, `teardown`, `seed-findings`, `tf.sh` |
| [`.github/workflows`](.github/workflows) | `terraform.yml`, `app.yml`, `drift.yml` |
| [`docs/carenotes`](docs/carenotes) | Deployment guide, architecture and decisions |
| [`docs/runbooks`](docs/runbooks) | SCC remediation, incident response, reliability and drills |

## Documentation

| Document | Purpose |
|---|---|
| [CareNotes architecture and decisions](docs/carenotes/ARCHITECTURE.md) | Design, trade-offs, best-practice deviations |
| [Deployment guide](docs/carenotes/DEPLOYMENT.md) | Step-by-step build, CI wiring, cost control |
| [Project Charter](docs/governance/PROJECT-CHARTER.md) | Scope and business outcomes |
| [Architecture Standards](docs/architecture/ARCHITECTURE-STANDARDS.md) | Design and security principles |
| [GCP Organization Hierarchy](docs/architecture/GCP-ORGANIZATION-HIERARCHY.md) | Folders and projects |
| [Phase 0 — Terraform Bootstrap](docs/00-terraform-bootstrap/README.md) | Bootstrap design history |
| [Privacy & Control Frameworks](docs/governance/PRIVACY-AND-CONTROL-FRAMEWORKS.md) | HIPAA / NIST / CIS references |

**Scope decision (Nov 2026):** the platform uses native Google Cloud security only (no third-party NGFW appliance), and Azure and VMware migration are out of scope for this build. They remain in the original roadmap docs for reference.

## Engineering principles

Terraform-managed infrastructure, least-privilege access, reviewed changes, observe-then-enforce guardrails, tested controls, operational runbooks and cost governance. This is a **portfolio project**, not an official environment of any employer. Never commit credentials, state, real identifiers or real patient data. Security control mapping does not imply HIPAA certification.
