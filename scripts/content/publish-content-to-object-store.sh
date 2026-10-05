#!/usr/bin/env bash
# Publish exported editorial JSON and media to an S3-compatible bucket.
# Accepts S3_* or legacy R2_* environment variables.
# Used by `pandorga publish` and CI content pipelines.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SITE_ROOT="${PANDORGA_SITE_ROOT:-$ROOT}"
EXPORT_ROOT="${1:-$SITE_ROOT/_content_json}"

# Prefer S3_* names; fall back to R2_* for Cloudflare R2 callers.
S3_ENDPOINT="${S3_ENDPOINT:-${R2_ENDPOINT:-}}"
S3_BUCKET="${S3_BUCKET:-${R2_BUCKET:-}}"
S3_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID:-${R2_ACCESS_KEY_ID:-}}"
S3_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY:-${R2_SECRET_ACCESS_KEY:-}}"
S3_REGION="${S3_REGION:-${R2_REGION:-auto}}"

: "${S3_ENDPOINT:?Set S3_ENDPOINT or R2_ENDPOINT (S3-compatible API URL)}"
: "${S3_BUCKET:?Set S3_BUCKET or R2_BUCKET}"
: "${S3_ACCESS_KEY_ID:?Set S3_ACCESS_KEY_ID or R2_ACCESS_KEY_ID}"
: "${S3_SECRET_ACCESS_KEY:?Set S3_SECRET_ACCESS_KEY or R2_SECRET_ACCESS_KEY}"

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$S3_REGION"

# Keep sync helper (still reads R2_* names) working.
export R2_ENDPOINT="$S3_ENDPOINT"
export R2_BUCKET="$S3_BUCKET"
export R2_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID"
export R2_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY"
export R2_REGION="$S3_REGION"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required for object-store publish." >&2
  exit 1
fi

run_ruby() {
  if command -v mise >/dev/null 2>&1; then
    mise exec -- ruby "$@"
  else
    ruby "$@"
  fi
}

sync_json_prefix() {
  local prefix="$1"
  local src="$EXPORT_ROOT/$prefix"
  if [ -d "$src" ]; then
    echo "==> Object store replace sync $prefix/"
    run_ruby "$ROOT/scripts/content/sync-content-json-to-r2.rb" "$EXPORT_ROOT" "$prefix"
  fi
}

echo "==> Publishing content JSON to bucket: ${S3_BUCKET}"
echo "==> Endpoint: ${S3_ENDPOINT}"
sync_json_prefix collections
sync_json_prefix data
sync_json_prefix pages

echo "==> Upload manifest.json"
aws s3 cp "$EXPORT_ROOT/manifest.json" "s3://${S3_BUCKET}/manifest.json" \
  --endpoint-url "$S3_ENDPOINT" \
  --cache-control "public,max-age=60" \
  --content-type "application/json"

MEDIA_ROOT="$SITE_ROOT/content/media"
if [ -d "$MEDIA_ROOT" ]; then
  echo "==> Sync media/"
  aws s3 sync "$MEDIA_ROOT" "s3://${S3_BUCKET}/media" \
    --endpoint-url "$S3_ENDPOINT" \
    --delete \
    --size-only \
    --cache-control "public,max-age=31536000,immutable"
fi

echo "==> Object-store publish complete"
