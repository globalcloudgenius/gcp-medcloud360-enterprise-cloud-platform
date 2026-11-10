#!/usr/bin/env bash
# Observe -> enforce. Turns on CMEK enforcement for the prod folder and moves the
# VPC Service Controls perimeter from dry run to ENFORCED.
#   ./scripts/enforce-guardrails.sh          # enforce
#   ./scripts/enforce-guardrails.sh --undo   # roll back to observe mode
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config/mc360.tfvars"
export AUTO_APPROVE=1

if [[ "${1:-}" == "--undo" ]]; then CMEK=false; DRY=true; else CMEK=true; DRY=false; fi

if [[ "$DRY" == "false" ]]; then
  echo "Dry-run VPC-SC violations from the last 24h (review before enforcing):"
  ORG="$(sed -nE 's/^org_id[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$CONFIG")"
  gcloud logging read --organization="$ORG" --freshness=1d --limit=20 \
    'protoPayload.metadata.@type="type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata" AND protoPayload.metadata.dryRun=true' \
    --format='table(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.methodName,protoPayload.metadata.violationReason)' || true
  if [[ "${YES:-}" != "1" ]]; then
    read -r -p "Enforce CMEK and the perimeter now? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] || exit 1
  fi
fi

sed -i -E "s/^(enforce_cmek[[:space:]]*=[[:space:]]*).*/\1$CMEK/; s/^(vpcsc_dry_run[[:space:]]*=[[:space:]]*).*/\1$DRY/" "$CONFIG"
"$ROOT/scripts/tf.sh" 03-security apply
"$ROOT/scripts/tf.sh" 07-perimeter apply
"$ROOT/scripts/tf.sh" 07-perimeter output mode
echo "Re-run Platform Proof in the portal: the CMEK and exfiltration checks should now PASS."
