#!/usr/bin/env bash
# Builds the CareNotes image, pushes it to Artifact Registry and rolls it out to every
# Cloud Run service and job. Used by deploy-all.sh and mirrored by .github/workflows/app.yml.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${MC360_CONFIG:-$ROOT/config/mc360.tfvars}"

proj() { sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" "$CONFIG" | head -1; }
cfg()  { sed -nE "s/^$1[[:space:]]*=[[:space:]]*\"?([^\"#]*)\"?.*/\1/p" "$CONFIG" | head -1 | xargs; }

APP="$(proj prod_app)"; OBS="$(proj observability)"
REGION="$(cfg region)"; DR="$(cfg dr_region)"; DR_ON="$(cfg enable_dr_region)"
TAG="${IMAGE_TAG:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%s)}"
REPO="$REGION-docker.pkg.dev/$APP/carenotes/carenotes"

echo "==> Building $REPO:$TAG"
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
  gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet >/dev/null
  docker build -t "$REPO:$TAG" -t "$REPO:latest" "$ROOT/app/carenotes"
  docker push "$REPO:$TAG"; docker push "$REPO:latest"
else
  echo "    docker not available — building with Cloud Build"
  gcloud builds submit "$ROOT/app/carenotes" --project "$APP" --region "$REGION" --tag "$REPO:$TAG"
fi

DIGEST="$(gcloud artifacts docker images describe "$REPO:$TAG" --format='value(image_summary.digest)')"
IMAGE="$REPO@$DIGEST"   # deploy by digest: what was scanned is exactly what runs
echo "==> Deploying $IMAGE"

REGIONS=("$REGION"); [[ "$DR_ON" == "true" ]] && REGIONS+=("$DR")
for r in "${REGIONS[@]}"; do
  gcloud run deploy carenotes-portal --image "$IMAGE" --region "$r" --project "$APP" --quiet
done
gcloud run deploy carenotes-processor --image "$IMAGE" --region "$REGION" --project "$APP" --quiet
gcloud run deploy scc-router --image "$IMAGE" --region "$REGION" --project "$OBS" --quiet
for j in hl7-sim daily-report; do
  gcloud run jobs update "$j" --image "$IMAGE" --region "$REGION" --project "$APP" --quiet
done
echo "==> CareNotes $TAG deployed"
