#!/usr/bin/env bash
# Single verification entry point (local == CI). Refs: integration.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== pandorga validate =="

if command -v mise >/dev/null 2>&1; then
  RUBY=(mise exec -- ruby)
else
  RUBY=(ruby)
fi

export RUBYOPT="-I${ROOT}/lib${RUBYOPT:+ $RUBYOPT}"

failed=0
for test in scripts/test/test-*.rb; do
  echo "-- ${test}"
  if ! "${RUBY[@]}" "$test"; then
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "VALIDATE FAILED"
  exit 1
fi

echo "VALIDATE OK"
