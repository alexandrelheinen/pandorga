#!/usr/bin/env bash
# Compatibility wrapper — prefer publish-content-to-object-store.sh (S3_* or R2_*).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$ROOT/publish-content-to-object-store.sh" "$@"
