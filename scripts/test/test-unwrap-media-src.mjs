#!/usr/bin/env node
// Mirrors unwrapMediaSrc in content-runtime/10-utils.html and md-to-pdf.mjs.
function unwrapMediaSrc(path) {
  const value = String(path == null ? '' : path).trim();
  if (!value) return '';
  const md = value.match(/^\[([^\]]*)\]\(([^)\s]+)\)\s*$/);
  if (md) return String(md[2] || '').trim();
  const angle = value.match(/^<([^>\s]+)>\s*$/);
  if (angle) return String(angle[1] || '').trim();
  return value;
}

const cases = [
  ['https://example.com/a.png', 'https://example.com/a.png'],
  [
    '[https://example.com/a.png](https://example.com/a.png)',
    'https://example.com/a.png',
  ],
  ['[label](https://example.com/a.png)', 'https://example.com/a.png'],
  ['<https://example.com/a.png>', 'https://example.com/a.png'],
  ['media/images/a.png', 'media/images/a.png'],
  ['[not a full](link) leftover', '[not a full](link) leftover'],
  ['', ''],
];

let failed = 0;
for (const [input, expected] of cases) {
  const got = unwrapMediaSrc(input);
  if (got !== expected) {
    console.error(`FAIL: ${JSON.stringify(input)} → ${JSON.stringify(got)} (want ${JSON.stringify(expected)})`);
    failed += 1;
  }
}

if (failed) {
  console.error(`unwrapMediaSrc: ${failed} failure(s)`);
  process.exit(1);
}
console.log(`PASS: unwrapMediaSrc (${cases.length} cases)`);
