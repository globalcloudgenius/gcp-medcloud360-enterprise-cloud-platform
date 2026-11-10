#!/usr/bin/env bash
# Grants the signed-in administrator the organization and project roles Terraform needs
# when running locally (stage 00 and deploy-all.sh). Idempotent; requires Organization
# Administrator. After CI is wired, day-to-day changes run as mc360-tf-apply instead.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config/mc360.tfvars"
ACCOUNT="$(gcloud config get-value account 2>/dev/null)"
MEMBER="user:$ACCOUNT"
ORG="$(sed -nE 's/^org_id[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$CONFIG")"
BILLING="$(sed -nE 's/^billing_account[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$CONFIG")"
mapfile -t PROJECTS < <(sed -nE 's/^[[:space:]]*[a-z_]+[[:space:]]*=[[:space:]]*"(mc360-prj-[^"]*)".*/\1/p' "$CONFIG")

ORG_ROLES=(
  roles/accesscontextmanager.policyAdmin roles/billing.projectManager roles/compute.orgFirewallPolicyAdmin
  roles/compute.orgSecurityResourceAdmin roles/compute.xpnAdmin roles/iam.organizationRoleViewer
  roles/logging.configWriter roles/orgpolicy.policyAdmin roles/resourcemanager.organizationViewer
  roles/resourcemanager.tagAdmin roles/resourcemanager.tagUser roles/securitycenter.admin
)
PROJECT_ROLES=(
  roles/artifactregistry.admin roles/bigquery.admin roles/binaryauthorization.policyEditor roles/cloudkms.admin
  roles/cloudscheduler.admin roles/compute.admin roles/dlp.admin roles/dns.admin roles/iam.serviceAccountAdmin
  roles/iam.serviceAccountUser roles/iap.admin roles/logging.admin roles/monitoring.admin
  roles/networkconnectivity.hubAdmin roles/networkmanagement.admin roles/osconfig.osPolicyAssignmentAdmin
  roles/osconfig.patchDeploymentAdmin roles/pubsub.admin roles/resourcemanager.projectIamAdmin roles/run.admin
  roles/secretmanager.admin roles/serviceusage.serviceUsageAdmin roles/storage.admin roles/iam.workloadIdentityPoolAdmin
)

echo "Granting $MEMBER the MedCloud360 deployer roles (org $ORG, ${#PROJECTS[@]} projects)…"
for r in "${ORG_ROLES[@]}"; do
  gcloud organizations add-iam-policy-binding "$ORG" --member="$MEMBER" --role="$r" --condition=None --quiet >/dev/null
done
for p in "${PROJECTS[@]}"; do
  for r in "${PROJECT_ROLES[@]}"; do
    gcloud projects add-iam-policy-binding "$p" --member="$MEMBER" --role="$r" --condition=None --quiet >/dev/null
  done
done
gcloud billing accounts add-iam-policy-binding "$BILLING" --member="$MEMBER" --role=roles/billing.admin --quiet >/dev/null 2>&1 \
  || echo "  (billing admin grant skipped — you are probably already the billing account admin)"
echo "Done. IAM changes can take up to 2 minutes to propagate."
