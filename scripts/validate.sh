#!/usr/bin/env bash
# Platform gates that run against the gem / fixtures / examples.
# Content-corpus gates stay on the consuming site (website).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== pandorga validate =="

# Prefer Bundler so gemspec deps (jekyll, …) resolve the same way in CI and
# local checkouts. Plain `ruby` only sees the system/mise gem path.
if [[ -f "${ROOT}/Gemfile.lock" ]] && command -v bundle >/dev/null 2>&1; then
  if command -v mise >/dev/null 2>&1; then
    RUBY=(mise exec -- bundle exec ruby)
  else
    RUBY=(bundle exec ruby)
  fi
elif command -v mise >/dev/null 2>&1; then
  RUBY=(mise exec -- ruby)
else
  RUBY=(ruby)
fi

export RUBYOPT="-I${ROOT}/lib${RUBYOPT:+ $RUBYOPT}"

# Explicit allowlist — do not glob site-corpus tests copied during extraction.
TESTS=(
  scripts/test/test-doctor.rb
  scripts/test/test-new.rb
  scripts/test/test-export.rb
  scripts/test/test-registry-home.rb
  scripts/test/test-template-packages.rb
  scripts/test/test-dual-template-instances.rb
  scripts/test/test-dual-template-runtime.rb
  scripts/test/test-install-functions.rb
  scripts/test/test-publish-site-root.rb
  scripts/test/test-no-personal-data.rb
  scripts/test/test-configuration-doc.rb
  scripts/test/test-cv-export-contract.rb
  scripts/test/test-css-structure.rb
  scripts/test/test-form-control-theming.rb
  scripts/test/test-listing-filter-contract.rb
  scripts/test/test-studio-api-contract.rb
  scripts/test/test-studio-rewrite-api-contract.rb
  scripts/test/test-studio-schema-composition.rb
  scripts/test/test-text-excerpt.rb
  scripts/test/test-git-chronology.rb
  scripts/test/test-math-row-breaks.rb
  scripts/test/test-detail-render-parity.rb
  scripts/test/test-absent-field-absent-element.rb
  scripts/test/test-ledger-blocks.rb
  scripts/test/test-home-band-art.rb
  scripts/test/test-hero-name.rb
  scripts/test/test-r2-json-sync.rb
  scripts/test/test-writing-slug-limits.rb
  scripts/test/test-examples-build.rb
  scripts/test/test-validate-allowlist.rb
  scripts/test/test-shell-a11y.rb
  scripts/test/test-hydrate-reserve.rb
  scripts/test/test-css-delivery.rb
  scripts/test/test-discovery.rb
)

failed=0
for test in "${TESTS[@]}"; do
  if [[ ! -f "$test" ]]; then
    echo "-- ${test} (missing)"
    failed=1
    continue
  fi
  echo "-- ${test}"
  if ! "${RUBY[@]}" "$test"; then
    failed=1
  fi
done

echo "-- scripts/test/test-studio-pipeline-config.mjs"
if ! node scripts/test/test-studio-pipeline-config.mjs; then
  failed=1
fi

echo "-- scripts/test/test-studio-pipeline-focus.mjs"
if ! node scripts/test/test-studio-pipeline-focus.mjs; then
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "VALIDATE FAILED"
  exit 1
fi

echo "VALIDATE OK"
