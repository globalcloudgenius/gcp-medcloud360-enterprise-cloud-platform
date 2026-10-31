# Privacy, Security and Control Frameworks

**Project:** MedCloud 360 · **Status:** Planned control mapping · **Data classification:** Synthetic healthcare-style data only

## Source requirements and scope

The reference Senior Cloud Engineer job description explicitly mentions infrastructure that supports **PII** (personally identifiable information) and **PHI** (protected health information), cloud-security vulnerability identification and remediation, cloud governance, security analytics, VMware migration, GCP, Azure and Terraform. **It does not name a specific compliance framework or require certification.**

MedCloud 360 uses simulated workloads and generated synthetic records to demonstrate design and technical safeguards. It does **not** ingest, copy, publish or process real patient records. Synthetic datasets must not be constructed by reproducing or lightly altering real patient information.

## Framework and policy references

The following are **project-selected implementation references**, not frameworks explicitly listed in the job description and not claims of external attestation.

| Reference | Application to MedCloud 360 | Deliverable |
| --- | --- | --- |
| HIPAA Privacy Rule (where legally applicable) | PHI access, use/disclosure and minimum-necessary concepts | Fictional-data handling and access-design review |
| HIPAA Security Rule (where legally applicable) | Administrative, physical and technical safeguard concepts for ePHI | Technical safeguard-to-test mapping |
| HIPAA Breach Notification Rule (where legally applicable) | Incident detection, escalation and notification assessment concepts | Incident response tabletop, with no real incident claims |
| NIST Cybersecurity Framework 2.0 | Govern, Identify, Protect, Detect, Respond, Recover | Control coverage and evidence index |
| NIST SP 800-53 Rev. 5 | Selected AC, AU, CM, CP, IA, IR, RA, SC and SI families | Target control and implementation evidence |
| CIS Controls v8 / applicable cloud benchmarks | Secure configuration, access control, vulnerability management and logging | Hardened configuration checklist and validation results |
| Google Cloud and Microsoft Azure security guidance | Native policy, IAM, encryption, logging, network and workload security patterns | GCP/Azure configuration tests |

**Applicability:** HIPAA applies based on covered-entity/business-associate status and regulated data processing, not merely because a project uses healthcare terminology. NIST/CIS mappings are voluntary design references unless independently required. No HIPAA compliance, audit, regulatory approval or certification is claimed by these documents.

## Privacy and sensitive-data engineering requirements

| Area | Required practice | Evidence to collect |
| --- | --- | --- |
| Data minimization | Synthetic test records only; no live PII/PHI | Data provenance and sample-generation procedure |
| Classification and inventory | Label data stores, permitted flows, ownership and retention | Data-flow diagram and asset inventory |
| Identity and authorization | Least-privilege IAM, MFA for human admins, service-account separation | Positive/negative permission tests |
| Encryption | TLS in transit; encryption at rest; review Key Management requirements | Configuration and connectivity validation |
| Network isolation | Private database access, VPC restrictions, documented cross-cloud trust boundaries | Allowed/denied flow test results |
| Audit and monitoring | Centralized administrative, data-access and security-event logging subject to service capabilities | Event generation, alert and log-retention tests |
| Vulnerability management | Native GCP/Azure tools; optional Wiz-equivalent CNAPP assessment, patch/remediate/retest | Finding, priority, change and retest evidence |
| Retention and disposal | Defined synthetic-data lifetime, tested deletion and backup lifecycle | Retention setting and teardown verification |
| Incident response | Detect, contain, escalate, recover and conduct post-incident review | Synthetic incident simulation and runbook |
| CI/CD and evidence privacy | No secrets, state files, credentials, real identities or unredacted screenshots in GitHub | Secrets checks and sanitization review |

## Phase integration

- **Phases 0–2:** IAM, policy-as-code, asset scoping, networking boundaries, audit baselines and Terraform state protection.
- **Phases 3–7:** Security inspection, Azure controls, hybrid trust boundaries, private workloads and migration data handling.
- **Phase 8:** Vulnerability remediation, selected NIST/CIS/HIPAA safeguard mapping and controlled test cases.
- **Phases 9–11:** Incident response, recovery, analytics/AI access reviews, evidence traceability and validation.

**Evidence rule:** Each claimed implemented safeguard requires a configuration reference, test method, observed result, date and sanitization check. Until tested, record as **Planned**.
