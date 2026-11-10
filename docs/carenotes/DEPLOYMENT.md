# Deploying MedCloud360 CareNotes

Everything is Terraform, run in a fixed order by one script. Run it from **Cloud Shell**
(Terraform, gcloud and Docker are already installed) while signed in as your organization
administrator.

## 1. Prerequisites (once)

| Item | Check |
|---|---|
| Organization `isaacobaro01-org` with the 6 `fld-mc360-*` folders and 7 `mc360-prj-*` projects | Already in place |
| Billing linked to all 7 projects | `discover.sh` warns if one is missing |
| You are Organization Administrator and Billing Account Administrator | `deploy-all.sh` grants the rest |
| `mc360-prj-network` has **no `default` VPC** (it would take one of the 4 VPC slots) | `discover.sh` warns and prints the delete command |
| SCC Standard active on the organization | Already active |

## 2. Deploy (about 30–40 minutes the first time)

```bash
git clone https://github.com/globalcloudgenius/gcp-medcloud360-enterprise-cloud-platform.git
cd gcp-medcloud360-enterprise-cloud-platform
./scripts/discover.sh      # reads your org and writes config/mc360.tfvars (git-ignored)
./scripts/deploy-all.sh    # stages 00 -> 08 + builds and deploys the app
```

`deploy-all.sh` runs, in order:

| # | Stage | Builds |
|---|---|---|
| 00 | bootstrap | APIs, state bucket (if missing), Workload Identity Federation, CI identities — then migrates its own state to GCS |
| 01 | org | 13 org policies + sandbox exception + custom Secure Boot constraint, tags, org firewall baseline, audit sinks (7-year GCS, BigQuery SIEM, log bucket), Data Access logs, budgets |
| 02 | network | 4 VPCs, NCC STAR hub, Shared VPC, subnet IAM, NAT, restricted/private Google APIs, DNS, secure tags, firewall policies (+ optional HA VPN lab) |
| 03 | security | KMS keys + service-agent grants, CMEK policies (off until enforced), workload identities, HL7 TLS secrets, SCC notifications/export/mute |
| 04 | data | CMEK buckets, BigQuery (CMEK), Pub/Sub, HL7→BigQuery subscription, DLP templates, least-privilege grants |
| 05 | compute | HL7 MLLP/TLS gateway: regional MIG (3 zones), internal TCP LB, VM Manager patching + OS policies, snapshots |
| 06 | app | Artifact Registry, Cloud Run portal (2 regions) + processor + jobs + scc-router, Pub/Sub push, Scheduler, global LB + Cloud Armor + IAP |
| — | app build | `deploy-app.sh`: build → push → deploy by digest |
| 07 | perimeter | VPC Service Controls around prod-app + prod-data, **dry run** |
| 08 | observability | Metrics scope, security detections + alerts, SLO + burn-rate alert, connectivity tests, dashboard, and the 14th org policy (domain-restricted sharing) applied last |

Re-running is safe. A stage that fails on first run because a brand-new API or IAM grant has
not propagated is retried automatically after 60 seconds.

## 3. Wire GitHub Actions (once)

```bash
gh auth login
./scripts/tf.sh 00-bootstrap output -raw github_setup_commands | bash
```

Then in GitHub → Settings → Environments create **`production`** with yourself as required
reviewer. From then on: PRs get a plan comment; **Actions → terraform → Run workflow** applies
one stage after approval; pushes to `app/carenotes` build, scan and deploy automatically.

## 4. Use it

1. `./scripts/tf.sh 06-app output portal_url` — open it (Google-managed certificate: 15–60 min on first deploy).
2. **Notes**: process the sample note → see PHI found, de-identified text and the Gemini summary.
3. **HL7 feed**: send 100 messages → watch them land in BigQuery.
4. **Platform Proof**: 12 live checks. CMEK and exfiltration show WARN until you enforce.

## 5. Observe, then enforce

```bash
./scripts/enforce-guardrails.sh          # shows dry-run violations, then enforces CMEK + VPC-SC
./scripts/enforce-guardrails.sh --undo   # rollback
```

Re-run Platform Proof: every guardrail should now be **PASS**.

## 6. Cost control

| Command | Effect |
|---|---|
| `./scripts/teardown.sh compute` | Stops the HL7 MIG, load balancer, DR region and VPN (the billable demo parts) |
| `./scripts/deploy-all.sh` with flags back to `true` | Brings them back |
| `./scripts/teardown.sh all` | Destroys everything except bootstrap, KMS keys and the 7-year audit bucket |

Budgets alert at 50 %, 80 % and 100 % forecast of `monthly_budget_usd` per project.

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| A stage fails with "API has not been used" or "permission denied" right after a new API/role | Eventual consistency | `deploy-all.sh` retries once; otherwise wait 2 minutes and re-run |
| Stage 02 fails: network quota exceeded | The `default` VPC still exists in mc360-prj-network | Delete it (command printed by `discover.sh`) |
| Portal shows a certificate error | Google-managed certificate still provisioning | Wait 15-60 min; `gcloud compute ssl-certificates list --project mc360-prj-prod-app` |
| IAP denies you although you are in `iap_members` | Signed in with a consumer (gmail) account: the Google-managed IAP OAuth client only serves users of your organization | Use an account in your Cloud Identity domain, or configure an external OAuth client for IAP |
| Stage 07: access policy already exists | An org can have only one | `discover.sh` fills `access_policy_id`; re-run it |
| After enforcing VPC-SC, Terraform from your laptop is refused | You are outside the perimeter and not in `admin_members` | Add yourself to `admin_members` and re-apply 07 (its API is never restricted) |
| HL7 job fails to connect | MIG still booting (≈3 min) or firewall rule changed | `gcloud compute instance-groups managed list-instances hl7-gw-mig --region us-central1 --project mc360-prj-prod-app`; Connectivity Tests |
| BigQuery query in prod fails mentioning CMEK | A query without the CMEK setting after `enforce_cmek = true` | The app always passes the key (`app/carenotes/carenotes/bq.py`); for ad-hoc queries add `--destination_kms_key` |
