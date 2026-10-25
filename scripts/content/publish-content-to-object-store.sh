#!/usr/bin/env bash
# Publish exported editorial JSON and media to an S3-compatible bucket.
# Accepts S3_* or legacy R2_* environment variables.
# Used by `pandorga publish` and CI content pipelines.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# When this script lives in an installed (or checked-out) gem, ROOT is the gem
# tree — not the consumer site. Media sync must use the site root; without it
# we used to skip content/media silently and leave Studio uploads on GitHub
# only. Require an explicit site root whenever ROOT looks like the gem.
if [ -z "${PANDORGA_SITE_ROOT:-}" ] && [ -f "$ROOT/pandorga.gemspec" ]; then
  echo "error: PANDORGA_SITE_ROOT must be set when publish-content-to-object-store.sh runs from the pandorga gem." >&2
  echo "hint: export PANDORGA_SITE_ROOT to the Jekyll site root before exec (site wrappers must set this)." >&2
  exit 1
fi

SITE_ROOT="${PANDORGA_SITE_ROOT:-$ROOT}"
SITE_ROOT="$(cd "$SITE_ROOT" && pwd)"
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
  echo "==> Object store replace sync $prefix/"
  run_ruby "$ROOT/scripts/content/sync-content-json-to-r2.rb" "$EXPORT_ROOT" "$prefix"
}

MEDIA_ROOT="$SITE_ROOT/content/media"

sync_media() {
  echo "==> Sync media/ from ${MEDIA_ROOT}"
  aws s3 sync "$MEDIA_ROOT" "s3://${S3_BUCKET}/media" \
    --endpoint-url "$S3_ENDPOINT" \
    --delete \
    --size-only \
    --cache-control "public,max-age=31536000,immutable"
}

echo "==> Publishing content JSON to bucket: ${S3_BUCKET}"
echo "==> Endpoint: ${S3_ENDPOINT}"
echo "==> Site root: ${SITE_ROOT}"

# The prefixes are disjoint, so their syncs run as parallel jobs (PLT-AC-53).
# Each job logs to its own file; the logs print in a fixed order afterwards.
JOB_LOGS="$(mktemp -d)"
trap 'rm -rf "$JOB_LOGS"' EXIT
JOB_NAMES=()
JOB_PIDS=()

start_job() {
  local name="$1"
  shift
  ( "$@" ) > "$JOB_LOGS/$name.log" 2>&1 &
  JOB_NAMES+=("$name")
  JOB_PIDS+=("$!")
}

for prefix in collections data pages; do
  if [ -d "$EXPORT_ROOT/$prefix" ]; then
    start_job "$prefix" sync_json_prefix "$prefix"
  fi
done

if [ -d "$MEDIA_ROOT" ]; then
  start_job media sync_media
else
  echo "==> No content/media at ${MEDIA_ROOT} (skipping media sync)"
fi

FAILED=()
for i in "${!JOB_PIDS[@]}"; do
  if ! wait "${JOB_PIDS[$i]}"; then
    FAILED+=("${JOB_NAMES[$i]}")
  fi
  cat "$JOB_LOGS/${JOB_NAMES[$i]}.log"
done

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "error: object-store sync failed for: ${FAILED[*]}; manifest.json not uploaded." >&2
  exit 1
fi

# Readers start from the manifest, so it goes up only after every object it
# can lead to is in place.
echo "==> Upload manifest.json"
aws s3 cp "$EXPORT_ROOT/manifest.json" "s3://${S3_BUCKET}/manifest.json" \
  --endpoint-url "$S3_ENDPOINT" \
  --cache-control "public,max-age=60" \
  --content-type "application/json"

echo "==> Object-store publish complete"
