#!/usr/bin/env bash
# teardown.sh compute   — stop the billable demo pieces (HL7 MIG, load balancer, VPN, DR region)
# teardown.sh all       — destroy every stage in reverse order (KMS keys are kept: GCP never deletes them)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config/mc360.tfvars"
export AUTO_APPROVE=1
MODE="${1:-compute}"

setflag() { sed -i -E "s/^($1[[:space:]]*=[[:space:]]*).*/\1$2/" "$CONFIG"; }

case "$MODE" in
  compute)
    setflag enable_hl7_gateway false; setflag enable_portal_lb false
    setflag enable_hybrid_vpn false;  setflag enable_dr_region false
    "$ROOT/scripts/tf.sh" 02-network apply
    "$ROOT/scripts/tf.sh" 05-compute apply
    "$ROOT/scripts/tf.sh" 06-app apply
    echo "Billable demo pieces stopped. Turn them back on: set the enable_* flags to true and run ./scripts/deploy-all.sh"
    ;;
  all)
    read -r -p "Destroy ALL MedCloud360 resources (projects and folders stay)? type 'destroy': " a
    [[ "$a" == "destroy" ]] || exit 1
    setflag vpcsc_dry_run true; setflag enforce_cmek false
    "$ROOT/scripts/tf.sh" 07-perimeter apply   # lift the perimeter first so cleanup calls are not blocked
    "$ROOT/scripts/tf.sh" 03-security apply    # lift CMEK enforcement
    for s in 08-observability 07-perimeter 06-app 05-compute 04-data; do "$ROOT/scripts/tf.sh" "$s" destroy || true; done
    # KMS keys cannot be deleted in GCP: drop them from state, versions can be destroyed in the console.
    (cd "$ROOT/terraform/03-security" && for k in storage bigquery compute pubsub secrets; do
      terraform state rm "google_kms_crypto_key.key[\"$k\"]" >/dev/null 2>&1 || true; done
      terraform state rm google_kms_key_ring.prod >/dev/null 2>&1 || true)
    for s in 03-security 02-network 01-org; do "$ROOT/scripts/tf.sh" "$s" destroy || true; done
    echo "Kept: 00-bootstrap (state bucket + CI identity), KMS keys, 7-year audit bucket (retention policy)."
    ;;
  *) echo "usage: teardown.sh compute|all"; exit 1 ;;
esac
