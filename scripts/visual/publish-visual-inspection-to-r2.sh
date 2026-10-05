#!/usr/bin/env bash
# Upload visual-inspection PNG screenshots to Cloudflare R2.
# Used by .github/workflows/visual-inspection.yml (manual dispatch only).
set -euo pipefail

LOCAL_DIR="${1:?Usage: publish-visual-inspection-to-r2.sh <local-dir> <run-prefix> [subdir]}"
RUN_PREFIX="${2:?Usage: publish-visual-inspection-to-r2.sh <local-dir> <run-prefix> [subdir]}"
SUBDIR="${3:-}"

: "${R2_ENDPOINT:?Set R2_ENDPOINT}"
: "${R2_BUCKET:?Set R2_BUCKET}"
: "${R2_ACCESS_KEY_ID:?Set R2_ACCESS_KEY_ID}"
: "${R2_SECRET_ACCESS_KEY:?Set R2_SECRET_ACCESS_KEY}"

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${R2_REGION:-auto}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required." >&2
  exit 1
fi

if [ ! -d "$LOCAL_DIR" ]; then
  echo "Local directory not found: $LOCAL_DIR" >&2
  exit 1
fi

DEST="visual-inspection/${RUN_PREFIX}"
if [ -n "$SUBDIR" ]; then
  DEST="${DEST}/${SUBDIR}"
fi

echo "==> R2 sync ${LOCAL_DIR}/ → s3://${R2_BUCKET}/${DEST}/"
aws s3 sync "$LOCAL_DIR" "s3://${R2_BUCKET}/${DEST}/" \
  --endpoint-url "$R2_ENDPOINT" \
  --exclude "*" \
  --include "*.png" \
  --cache-control "public,max-age=31536000,immutable" \
  --content-type "image/png"

echo "==> Visual inspection upload complete: ${DEST}/"
