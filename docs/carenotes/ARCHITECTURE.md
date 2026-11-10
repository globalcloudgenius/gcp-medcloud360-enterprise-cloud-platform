# CareNotes — architecture, decisions and trade-offs

## Placement (existing projects, unchanged)

| Folder | Project | What runs there |
|---|---|---|
| fld-mc360-bootstrap | mc360-prj-bootstrap | Terraform state, Workload Identity Federation, CI identities |
| fld-mc360-networking | mc360-prj-network | Shared VPC host: 4 VPCs, NCC hub, DNS, NAT, firewall policies, connectivity tests |
| fld-mc360-platform | mc360-prj-observability | Audit archive + BigQuery SIEM, security log bucket, SCC topic/export, scc-router, monitoring |
| fld-mc360-prod | mc360-prj-prod-app | Cloud Run portal/processor/jobs, HL7 MIG, LB + Armor + IAP, Artifact Registry, secrets |
| fld-mc360-prod | mc360-prj-prod-data | KMS keys, CMEK buckets, BigQuery, Pub/Sub, DLP templates |
| fld-mc360-nonprod | mc360-prj-dev | Shared VPC service project (nonprod subnet) |
| fld-mc360-nonprod | mc360-prj-test | Self-test targets, SCC seed lab, optional simulated clinic (HA VPN) |
| fld-mc360-sandbox | — | Only folder where external IPs are allowed |

## Network

| VPC | CIDR | NCC group | Purpose |
|---|---|---|---|
| mc360-vpc-hub | 10.40.0.0/16 | center | Shared services, HA VPN lab |
| mc360-vpc-security | 10.43.0.0/16 | center | Security tooling, admin access |
| mc360-vpc-prod | 10.42.0.0/16 | edge | PHI workloads (us-central1 + us-east4 subnets) |
| mc360-vpc-nonprod | 10.41.0.0/16 | edge | Dev and test |

Star topology: edges reach the center, never each other — prod/nonprod isolation is enforced by
routing, proven by a Connectivity Test (`mc360-prod-to-nonprod` = unreachable).
Prod resolves `*.googleapis.com` to **restricted.googleapis.com** (VPC-SC aware); others use private.googleapis.com.
Firewalls: org hierarchical baseline (SSH/RDP only from IAP), then a global network firewall policy
per VPC with secure-tag targeting and a logged default deny.

## Key decisions

| Decision | Why | Rejected alternative |
|---|---|---|
| Only what a managed service cannot do runs on VMs | HL7 MLLP is persistent raw TCP; Cloud Run is HTTP/gRPC only | Reports/exports on VMs (Cloud Run jobs + Scheduler do it with no servers) |
| Native GCP security only | Fewer moving parts and licenses; shows platform-native depth | Third-party NGFW appliance |
| Gemini sees de-identified text only | PHI minimisation; DLP redacts before any model call | Sending raw notes to the model |
| Observe → enforce for CMEK and VPC-SC | Enforcing first breaks Terraform and new buckets | Enforce on first apply |
| Identity-based perimeter ingress for CI | GitHub runners have no fixed IP or device posture | Access levels by IP |
| One state per stage | Blast radius; app changes can't touch org policy | Single root module |
| Outlier detection on the serverless backend | Serverless NEGs have no health checks; this gives real regional failover | Single region |
| Immutable MIG rollouts + OS Config patching | Template drift avoided; emergency patching still possible | In-place patching only |

## Documented deviations from Google's blueprint (because existing projects are kept)

| Deviation | Real-client version |
|---|---|
| 4 VPCs in one host project | One Shared VPC host per environment (separate IAM, quotas, blast radius) |
| KMS keys in mc360-prj-prod-data | Dedicated key project under a security folder |
| Audit logs share mc360-prj-observability | Dedicated logging project; lock the 7-year retention after sign-off |
| One apply identity for all stages | One CI identity per stage, scoped by branch |
| SCC Standard | Premium/Enterprise: Event Threat Detection, attack paths, HIPAA compliance reports |
| Self-signed internal CA for HL7 TLS | Certificate Authority Service |

## Job-requirement coverage (GCP)

| Requirement | Where |
|---|---|
| Design, implement, support GCP infrastructure | Stages 01–08 |
| IaaS / PaaS / SaaS | HL7 MIG / Cloud Run, Pub/Sub / BigQuery, Looker Studio-ready tables |
| Highly available, mission-critical | 2-region portal, 3-zone MIG, DLQ, SLO, DR runbook |
| Security tooling, vulnerabilities, remediation | SCC loop, VM Manager CVEs + patching, Trivy, Checkov, seed-and-fix |
| PHI / PII | DLP, CMEK, VPC-SC, IAP, Data Access logs, TLS |
| Terraform automation | Everything; CI with plan/approve/apply and drift detection |
| Security + data analytics infrastructure | BigQuery SIEM, HL7 analytics, daily exports |
| Networking and dependencies | NCC, Shared VPC, L4 + L7 load balancing, DNS, PSC/VIPs, firewall policies, HA VPN |
| Troubleshooting | Connectivity Tests, break-it drills, structured logs |
| Governance and documentation | Org policies, tags, budgets, runbooks, this document |
| Cost and performance | Budgets, feature flags, teardown, load tests, autoscaling |
| AI | Gemini via Vertex AI inside the perimeter |
