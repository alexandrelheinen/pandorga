#!/usr/bin/env node
// run-detail-parity-checks.mjs — the two detail paths must agree.
//
// A detail page is built twice. The public site renders it in the browser
// from _includes/content-runtime/50-detail.html, which delegates to the
// shared blocks; the private/studio build renders the same page at build time
// from _layouts/text.html, which reimplements the tag chips and the language
// pill in Liquid because Liquid cannot call the JS. That layout's own comment
// promises it emits "exactly the class contract" the runtime emits, and
// assets/css/ledger/detail.css styles both from one set of rules — so the day
// the two disagree, one of them loses its styling and the build says nothing.
//
// Prints the contract it found, for the Ruby gate to relay.

import fs from 'node:fs';
import path from 'node:path';
import { loadRuntime, toHtml, REPO_ROOT } from './load-runtime.mjs';

const LIQUID_DETAIL = path.join(REPO_ROOT, '_layouts', 'text.html');
const RUNTIME_DETAIL = path.join(REPO_ROOT, '_includes', 'content-runtime', '50-detail.html');
const BLOCKS = path.join(REPO_ROOT, '_includes', 'content-runtime', '43-blocks.html');

const { runtime } = loadRuntime();
const failures = [];

const liquid = fs.readFileSync(LIQUID_DETAIL, 'utf8');
const sidebar = fs.readFileSync(RUNTIME_DETAIL, 'utf8');

// The runtime detail view must delegate, not grow its own copy.
['renderTagChips'].forEach((block) => {
  if (!new RegExp(`${block}\\s*\\(`).test(sidebar)) {
    failures.push(
      `50-detail.html no longer calls ${block}; the detail sidebar has forked from the block library`
    );
  }
});

// Class contract: whatever the shared block emits, the Liquid copy must emit.
function classesIn(html) {
  const found = new Set();
  const attr = /class="([^"]*)"/g;
  let match;
  while ((match = attr.exec(html)) !== null) {
    match[1].split(/\s+/).filter(Boolean).forEach((name) => found.add(name));
  }
  return [...found];
}

const contract = [
  { label: 'tag chips (linked)', html: toHtml(runtime.renderTagChips(['Engineering'], { hrefFor: () => '/pages/articles/?tag=Engineering' })) },
  { label: 'tag chips (plain)', html: toHtml(runtime.renderTagChips(['Engineering'])) }
];

// A BEM-style modifier is interpolated on the Liquid side
// (`lang-pill--{{ page.language }}`), so the stem is what can be compared.
function emittedByLiquid(name) {
  if (liquid.includes(name)) return true;
  const stem = name.split('--')[0];
  return stem !== name && liquid.includes(`${stem}--`);
}

const reported = new Set();
contract.forEach(({ label, html }) => {
  if (!html) {
    failures.push(`${label}: the block rendered nothing for a populated field`);
    return;
  }
  classesIn(html).forEach((name) => {
    reported.add(name);
    if (!emittedByLiquid(name)) {
      failures.push(
        `_layouts/text.html never emits "${name}", which the runtime ${label} does. ` +
          'The private detail build would lose that styling.'
      );
    }
  });
});

// Language vocabulary: one table in JS, one chain of Liquid conditionals.
const blocks = fs.readFileSync(BLOCKS, 'utf8');
const table = blocks.match(/var LANGUAGE_LABELS = \{([\s\S]*?)\};/);
if (!table) {
  failures.push('could not find LANGUAGE_LABELS in 43-blocks.html');
} else {
  const runtimeLabels = {};
  table[1].replace(/(\w+)\s*:\s*'([^']*)'/g, (_, code, label) => {
    runtimeLabels[code] = label;
    return '';
  });

  const liquidLabels = {};
  liquid.replace(
    /page\.language\s*==\s*"(\w+)"\s*%\}\{%\s*assign\s+lang_label\s*=\s*"([^"]*)"/g,
    (_, code, label) => {
      liquidLabels[code] = label;
      return '';
    }
  );

  if (Object.keys(liquidLabels).length === 0) {
    failures.push('found no lang_label assignments in _layouts/text.html; the scan has drifted');
  }

  const codes = new Set([...Object.keys(runtimeLabels), ...Object.keys(liquidLabels)]);
  codes.forEach((code) => {
    if (runtimeLabels[code] !== liquidLabels[code]) {
      failures.push(
        `language "${code}" reads ${JSON.stringify(runtimeLabels[code])} in 43-blocks.html but ` +
          `${JSON.stringify(liquidLabels[code])} in _layouts/text.html`
      );
    }
  });

  console.log(`  language vocabulary agrees on ${[...codes].sort().join(', ')}`);
}

if (failures.length) {
  console.error(`The two detail paths disagree (${failures.length} problem(s)):`);
  failures.forEach((line) => console.error(`  - ${line}`));
  process.exit(1);
}

console.log(`  shared class contract: ${[...reported].sort().join(', ')}`);
