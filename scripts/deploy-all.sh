#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# deploy-all.sh — builds the whole MedCloud360 CareNotes platform in order.
#
#   ./scripts/discover.sh      # once: writes config/mc360.tfvars from your org
#   ./scripts/deploy-all.sh    # this script (about 25-40 minutes the first time)
#
# Safe to re-run: every stage is idempotent. Guardrails start in OBSERVE mode
# (CMEK not enforced, VPC-SC dry run); turn them on with ./scripts/enforce-guardrails.sh
# -----------------------------------------------------------------------------
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config/mc360.tfvars"
export AUTO_APPROVE=1

say() { printf '\n\033[1;34m==== %s ====\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v terraform >/dev/null || die "terraform not found (Cloud Shell has it; or install 1.6+)"
command -v gcloud >/dev/null || die "gcloud not found"
[[ -f "$CONFIG" ]] || die "Missing $CONFIG — run ./scripts/discover.sh first"

# Application Default Credentials are what Terraform uses.
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  say "Application Default Credentials needed"
  gcloud auth application-default login
fi
BOOT="$(sed -nE 's/^[[:space:]]*bootstrap[[:space:]]*=[[:space:]]*"(mc360-prj-[^"]*)".*/\1/p' "$CONFIG" | head -1)"
gcloud auth application-default set-quota-project "$BOOT" >/dev/null 2>&1 || true

STAGES=(00-bootstrap 01-org 02-network 03-security 04-data 05-compute 06-app)
LATE_STAGES=(07-perimeter 08-observability)

echo "This deploys into the organization in $CONFIG:"
grep -E '^(org_id|billing_account|state_bucket|enforce_cmek|vpcsc_dry_run|enable_[a-z_]+)' "$CONFIG" | sed 's/^/  /'
if [[ "${YES:-}" != "1" ]]; then
  read -r -p "Continue? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] || exit 1
fi

say "Deployer roles for $(gcloud config get-value account 2>/dev/null)"
"$ROOT/scripts/grant-admin-roles.sh"

apply_stage() {
  local stage="$1"
  say "Stage $stage"
  if ! "$ROOT/scripts/tf.sh" "$stage" apply; then
    # New APIs, service agents and IAM grants are eventually consistent: one retry is normal.
    echo "Retrying $stage in 60s (eventual consistency of new APIs / IAM)…"
    sleep 60
    "$ROOT/scripts/tf.sh" "$stage" apply
  fi
}

for s in "${STAGES[@]}"; do apply_stage "$s"; done

say "Build and deploy the CareNotes image"
"$ROOT/scripts/deploy-app.sh"

for s in "${LATE_STAGES[@]}"; do apply_stage "$s"; done

say "Done"
"$ROOT/scripts/tf.sh" 06-app output portal_url || true
"$ROOT/scripts/tf.sh" 07-perimeter output mode || true
cat <<'NEXT'

Next steps
  1. Wire CI once:        ./scripts/tf.sh 00-bootstrap output -raw github_setup_commands | bash
  2. Open the portal URL above (the managed certificate can take 15-60 minutes on first deploy).
  3. Upload a note, send HL7 messages, open Platform Proof.
  4. Review dry-run violations, then:  ./scripts/enforce-guardrails.sh
  5. End of day:                        ./scripts/teardown.sh compute   (stops the billable pieces)
NEXT
