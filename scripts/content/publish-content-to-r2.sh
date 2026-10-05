#!/usr/bin/env bash
# Publish exported editorial JSON and media to Cloudflare R2 (S3-compatible API).
# Used by .github/workflows/content-pipeline.yml and documented in docs/ops/cloudflare.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXPORT_ROOT="${1:-$ROOT/_content_json}"

: "${R2_ENDPOINT:?Set R2_ENDPOINT (e.g. https://<account_id>.r2.cloudflarestorage.com)}"
: "${R2_BUCKET:?Set R2_BUCKET}"
: "${R2_ACCESS_KEY_ID:?Set R2_ACCESS_KEY_ID}"
: "${R2_SECRET_ACCESS_KEY:?Set R2_SECRET_ACCESS_KEY}"

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${R2_REGION:-auto}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required (preinstalled on GitHub Actions ubuntu-latest)." >&2
  exit 1
fi

# Prefer mise when present: interactive shells often put rbenv first, and a
# bare `ruby` then fails on .ruby-version pins that only mise has installed.
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
    echo "==> R2 replace sync $prefix/"
    run_ruby "$ROOT/scripts/content/sync-content-json-to-r2.rb" "$EXPORT_ROOT" "$prefix"
  fi
}

echo "==> Publishing content JSON to R2 bucket: ${R2_BUCKET}"
echo "==> Replacing collections/, data/, and pages/ from the current Git export"
sync_json_prefix collections
sync_json_prefix data
sync_json_prefix pages

echo "==> Upload manifest.json"
# Always replace the index; it is small and lists the current object set.
aws s3 cp "$EXPORT_ROOT/manifest.json" "s3://${R2_BUCKET}/manifest.json" \
  --endpoint-url "$R2_ENDPOINT" \
  --cache-control "public,max-age=60" \
  --content-type "application/json"

if [ -d "$ROOT/content/media" ]; then
  echo "==> R2 sync media/"
  # --size-only: Actions checkout resets mtimes, so default size+mtime compare
  # would recopy every thumbnail. Cache-Control is applied on PUT only; do not
  # drop --delete. Same-size replacements are rare for editorial media.
  aws s3 sync "$ROOT/content/media" "s3://${R2_BUCKET}/media" \
    --endpoint-url "$R2_ENDPOINT" \
    --delete \
    --size-only \
    --cache-control "public,max-age=31536000,immutable"
fi

echo "==> R2 publish complete"
