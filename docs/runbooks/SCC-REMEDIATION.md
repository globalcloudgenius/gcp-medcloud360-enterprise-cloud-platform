# Runbook — Security Command Center finding remediation

**Trigger:** email "[SEC] Security Command Center HIGH/CRITICAL finding" (scc-router → log metric → alert).

| Step | Action | Where |
|---|---|---|
| 1. Triage | Open the finding link in the alert. Confirm asset, project, data class (tag `mc360-data-class`), exposure (internet-facing?). | SCC console, Cloud Asset Inventory |
| 2. Contain (CRITICAL only) | Lab project: scc-router already auto-remediated public buckets — check its `scc_remediation` log. Prod: break-glass via Privileged Access Manager, minimal change. | Logs Explorer |
| 3. Fix in code | PR in the stage that owns the resource. Never leave a console fix in place. | GitHub |
| 4. Prevent | Add or tighten a guardrail so it cannot recur: org policy (stage 01), Conftest/Checkov rule (CI), firewall policy (stage 02). | Terraform |
| 5. Verify | Finding shows **INACTIVE** after the next scan; Platform Proof still green. | SCC, portal |
| 6. Record | Add a row below. | This file |

## Remediation log

| Date | Finding | Severity | Root cause | Fix (PR) | Guardrail added | Time to remediate |
|---|---|---|---|---|---|---|
| | OPEN_SSH_PORT (lab-seed) | HIGH | Firewall rule 0.0.0.0/0:22 | `seed-findings.sh clean` | Org hierarchical deny 22/3389 (stage 01) + Conftest rule | |
| | FLOW_LOGS_DISABLED (lab-seed) | LOW | Subnet created by hand | delete subnet | All subnets created by stage 02 with flow logs | |
| | Basic role on SA (lab-seed) | MEDIUM | roles/editor granted | remove binding | IAM Recommender review weekly | |

## Accepted risk

Mute rule `mc360-sandbox-lab` (stage 03): findings in `fld-mc360-sandbox`. Owner: platform team. Review every 90 days.
