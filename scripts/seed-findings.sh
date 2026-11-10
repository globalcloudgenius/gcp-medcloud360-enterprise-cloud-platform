#!/usr/bin/env bash
# SCC "seed and fix" lab, in mc360-prj-test only (outside the PHI perimeter).
#   ./scripts/seed-findings.sh seed    # create 3 deliberate misconfigurations
#   ./scripts/seed-findings.sh clean   # remove them (the fix is then codified as a guardrail)
# Findings appear in Security Command Center (or Compliance Manager) within minutes to hours,
# flow to Pub/Sub -> scc-router -> alert, and to the BigQuery findings export.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config/mc360.tfvars"
P="$(sed -nE 's/^[[:space:]]*test[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$CONFIG")"
REGION="us-central1"

case "${1:-}" in
  seed)
    gcloud compute networks create lab-seed --project "$P" --subnet-mode=custom --quiet
    # 1. Subnet without VPC flow logs            -> FLOW_LOGS_DISABLED
    gcloud compute networks subnets create lab-seed-usc1 --project "$P" --network lab-seed \
      --region "$REGION" --range 172.31.0.0/24 --quiet
    # 2. SSH open to the whole internet          -> OPEN_SSH_PORT / OPEN_FIREWALL
    #    (the org hierarchical policy still denies it — defense in depth — but SCC flags the rule)
    gcloud compute firewall-rules create lab-seed-open-ssh --project "$P" --network lab-seed \
      --allow tcp:22 --source-ranges 0.0.0.0/0 --quiet
    # 3. Over-privileged identity (basic role)   -> PRIMITIVE_ROLES_USED / over-privileged SA
    gcloud iam service-accounts create lab-seed-overpriv --project "$P" --quiet
    gcloud projects add-iam-policy-binding "$P" --role roles/editor --condition=None --quiet \
      --member "serviceAccount:lab-seed-overpriv@$P.iam.gserviceaccount.com" >/dev/null
    # 4. Public bucket attempt — refused immediately by storage.publicAccessPrevention (preventive control)
    gcloud storage buckets create "gs://lab-seed-public-$RANDOM" --project "$P" --location "$REGION" --quiet || true
    echo "Seeded. Watch: Security Command Center > Findings (project $P), the scc-router logs, and your email."
    ;;
  clean)
    gcloud projects remove-iam-policy-binding "$P" --role roles/editor --condition=None --quiet \
      --member "serviceAccount:lab-seed-overpriv@$P.iam.gserviceaccount.com" >/dev/null || true
    gcloud iam service-accounts delete "lab-seed-overpriv@$P.iam.gserviceaccount.com" --project "$P" --quiet || true
    gcloud compute firewall-rules delete lab-seed-open-ssh --project "$P" --quiet || true
    gcloud compute networks subnets delete lab-seed-usc1 --project "$P" --region "$REGION" --quiet || true
    gcloud compute networks delete lab-seed --project "$P" --quiet || true
    for b in $(gcloud storage buckets list --project "$P" --format='value(name)' | grep '^lab-seed-public-' || true); do
      gcloud storage rm -r "gs://$b" --quiet || true
    done
    echo "Cleaned. SCC marks the findings INACTIVE on the next scan — record it in docs/runbooks/SCC-REMEDIATION.md."
    ;;
  *) echo "usage: seed-findings.sh seed|clean"; exit 1 ;;
esac
