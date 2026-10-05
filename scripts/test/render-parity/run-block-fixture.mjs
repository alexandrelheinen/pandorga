#!/usr/bin/env node
// run-block-fixture.mjs — render one shared ledger block and check its HTML.
//
// Sibling of run-fixture.mjs, which covers the Markdown body pipeline. This
// one covers _includes/content-runtime/43-blocks.html: the card, row, chip,
// pill and meta-strip renderers every listing now shares. It calls the real
// runtime through load-runtime.mjs rather than a second implementation, so a
// fixture fails when the shipped block changes, not when a copy drifts.
//
// Fixture shape:
//   name       label printed on success
//   block      function name on the ContentRuntime export
//   args       positional arguments; see hydrateArgs for the callable forms
//   empty      true  → the block must render nothing at all
//   selectors  must be present (see selectors.mjs for the vocabulary)
//   forbidden  must be absent — this is where the hard rule lives
//   contains   raw substrings that must appear (attributes, entities, text)
//   excludes   raw substrings that must not appear
//   counts     { "class-name": n } exact occurrence counts

import fs from 'node:fs';
import { loadRuntime, toHtml } from './load-runtime.mjs';
import { missingSelectors, presentSelectors, countClass } from './selectors.mjs';

// JSON cannot carry the callbacks the blocks accept, so fixtures declare them
// declaratively and this turns them into functions.
function hydrateArgs(value) {
  if (Array.isArray(value)) return value.map(hydrateArgs);
  if (value && typeof value === 'object') {
    if (typeof value.$hrefTemplate === 'string') {
      const template = value.$hrefTemplate;
      return (input) => template.replace('{value}', encodeURIComponent(String(input)));
    }
    const out = {};
    for (const [key, inner] of Object.entries(value)) out[key] = hydrateArgs(inner);
    return out;
  }
  return value;
}

const fixturePath = process.argv[2];
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const { runtime } = loadRuntime();

const block = runtime[fixture.block];
if (typeof block !== 'function') {
  console.error(`Fixture ${fixture.name}: the runtime exports no block named ${fixture.block}`);
  process.exit(1);
}

const html = toHtml(block(...hydrateArgs(fixture.args || [])));
const failures = [];

if (fixture.empty === true && html !== '') {
  failures.push(`expected no output, got ${JSON.stringify(html)}`);
}

const missing = missingSelectors(html, fixture.selectors);
if (missing.length) failures.push(`missing selectors: ${missing.join(', ')}`);

const present = presentSelectors(html, fixture.forbidden);
if (present.length) failures.push(`forbidden selectors rendered: ${present.join(', ')}`);

(fixture.contains || []).forEach((needle) => {
  if (!html.includes(needle)) failures.push(`missing substring: ${JSON.stringify(needle)}`);
});

(fixture.excludes || []).forEach((needle) => {
  if (html.includes(needle)) failures.push(`forbidden substring: ${JSON.stringify(needle)}`);
});

Object.entries(fixture.counts || {}).forEach(([className, expected]) => {
  const actual = countClass(html, className);
  if (actual !== expected) {
    failures.push(`expected ${expected} .${className}, got ${actual}`);
  }
});

if (failures.length) {
  console.error(`Fixture ${fixture.name} (${fixture.block}):`);
  failures.forEach((line) => console.error(`  - ${line}`));
  console.error(`  rendered: ${html}`);
  process.exit(1);
}

console.log(`Block ${fixture.name}: OK`);
