#!/usr/bin/env bash
# md-to-pdf.sh — Convert editorial Markdown (article, post, …) to a shareable PDF.
#
# Usage:
#   ./scripts/pdf/md-to-pdf.sh -i <path-to.md> -o <path-to.pdf>
#
# Examples:
#   ./scripts/pdf/md-to-pdf.sh \
#     -i content/collections/articles/2026-07-17-soft-drones-went-to-war.md \
#     -o /tmp/soft-drones-went-to-war.pdf
#
# Requirements (once):
#   npm ci --prefix scripts
#
# Spec: docs/features/markdown-pdf.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # scripts/ — holds package.json and node_modules

if [ ! -d "$NODE_DIR/node_modules/puppeteer" ] || [ ! -d "$NODE_DIR/node_modules/marked" ] || [ ! -d "$NODE_DIR/node_modules/js-yaml" ]; then
  echo "==> Installing script Node dependencies..."
  npm ci --prefix "$NODE_DIR"
fi

exec node "$SCRIPT_DIR/md-to-pdf.mjs" "$@"
