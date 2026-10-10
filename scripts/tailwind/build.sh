#!/usr/bin/env bash
# Rebuild assets/css/tailwind.css. Not part of the site build or validate.sh.
# Requires tailwindcss 3.4 and @tailwindcss/forms on NODE_PATH or via npx.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

npx --yes tailwindcss@3.4.17 -c scripts/tailwind/tailwind.config.js \
  -i scripts/tailwind/input.css \
  -o assets/css/tailwind.css \
  --minify

HEADER='/* Compiled Tailwind utilities (3.4.17, forms plugin). Replaces the Play CDN.
   Regenerate with scripts/tailwind/build.sh after adding a utility class. */
'
TMP="$(mktemp)"
printf '%s' "$HEADER" | cat - assets/css/tailwind.css > "$TMP"
mv "$TMP" assets/css/tailwind.css
