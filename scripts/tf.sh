#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# tf.sh — run one Terraform stage with the shared config and the GCS backend.
#
#   ./scripts/tf.sh <stage> <plan|apply|destroy|output|init> [extra terraform args]
#   ./scripts/tf.sh 02-network plan
#
# Every stage keeps its own state at gs://<state_bucket>/mc360/<stage>.
# CI (GitHub Actions) calls this same script, so laptop and pipeline match.
# -----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${MC360_CONFIG:-$ROOT/config/mc360.tfvars}"
TF="${TF_BIN:-terraform}"

STAGE="${1:?stage, e.g. 01-org}"
ACTION="${2:?plan|apply|destroy|output|init}"
shift 2 || true

DIR="$ROOT/terraform/$STAGE"
[[ -d "$DIR" ]] || { echo "No such stage: $STAGE" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG — run ./scripts/discover.sh first" >&2; exit 1; }

cfg() { sed -nE "s/^$1[[:space:]]*=[[:space:]]*\"?([^\"#]*)\"?.*/\1/p" "$CONFIG" | head -1 | xargs; }
BUCKET="$(cfg state_bucket)"
BOOT_PROJECT="$(sed -nE 's/^[[:space:]]*bootstrap[[:space:]]*=[[:space:]]*"(mc360-prj-[^"]*)".*/\1/p' "$CONFIG" | head -1)"
export GOOGLE_CLOUD_QUOTA_PROJECT="${GOOGLE_CLOUD_QUOTA_PROJECT:-$BOOT_PROJECT}"

cd "$DIR"

init_backend() {
  if [[ "$STAGE" == "00-bootstrap" ]] && ! gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1; then
    echo "==> State bucket gs://$BUCKET does not exist yet: running 00-bootstrap with local state first"
    printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
    "$TF" init -input=false -reconfigure >/dev/null
    return
  fi
  rm -f backend_override.tf
  "$TF" init -input=false -reconfigure \
    -backend-config="bucket=$BUCKET" \
    -backend-config="prefix=mc360/$STAGE" >/dev/null
}

migrate_bootstrap_state() {
  if [[ "$STAGE" == "00-bootstrap" && -f backend_override.tf ]]; then
    echo "==> Migrating 00-bootstrap state into gs://$BUCKET/mc360/00-bootstrap"
    rm -f backend_override.tf
    "$TF" init -input=false -migrate-state -force-copy \
      -backend-config="bucket=$BUCKET" \
      -backend-config="prefix=mc360/$STAGE"
    rm -f terraform.tfstate terraform.tfstate.backup
  fi
}

init_backend

case "$ACTION" in
  init)    : ;;
  plan)    "$TF" plan -input=false -var-file="$CONFIG" -out=tfplan "$@" ;;
  apply)
    if [[ -f tfplan && "${USE_SAVED_PLAN:-false}" == "true" ]]; then
      "$TF" apply -input=false tfplan
    else
      "$TF" apply -input=false -var-file="$CONFIG" ${AUTO_APPROVE:+-auto-approve} "$@"
    fi
    migrate_bootstrap_state
    ;;
  destroy) "$TF" destroy -input=false -var-file="$CONFIG" ${AUTO_APPROVE:+-auto-approve} "$@" ;;
  output)  "$TF" output "$@" ;;
  *) echo "Unknown action $ACTION" >&2; exit 1 ;;
esac
