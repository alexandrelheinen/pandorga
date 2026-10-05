#!/usr/bin/env node
// build-cv-pages-json.js — Write the cv-pages.json file used by take-screenshots.js.
//
// Extracts the 'cv' array from visual-inspection-pages.json and writes it as a flat
// array to cv-pages.json in the current working directory.
//
// Usage (run from repo root):
//   node scripts/visual/build-cv-pages-json.js [outputFile]
//
// Arguments:
//   outputFile — Output path for the JSON file (default: cv-pages.json)

'use strict';

const path = require('path');
const fs = require('fs');

const REPO_ROOT = path.resolve(path.join(__dirname, '..', '..'));

function main() {
  const outputFile = path.resolve(process.argv[2] || path.join(REPO_ROOT, 'cv-pages.json'));

  const cfg = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'visual-inspection-pages.json'), 'utf8')
  );

  fs.writeFileSync(outputFile, JSON.stringify(cfg.cv, null, 2), 'utf8');

  console.log(`Wrote ${cfg.cv.length} page(s) to ${outputFile}`);
  cfg.cv.forEach((p) => console.log(`  ${p.name} → ${p.url}`));
}

main();
