#!/usr/bin/env node
// run-field-flow-checks.mjs — every exported field must reach the view.
//
// Two silent-drop traps sit between the exporter and the page, and neither
// shows up in a build:
//
//  1. writingIndexAsListingItem() copies writing_index entries into the
//     { front_matter } shape the blocks read, through an explicit field
//     whitelist. A newly exported field is invisible until someone adds a
//     line there, and nothing complains — that is how `language` reached
//     writing_index.json and still never made it onto a card.
//
//  2. hydrateFrontMatter() merges the detail payload's top-level date and
//     last_updated into front_matter. It used to do that after an early
//     return that always fired for exported content, so no detail page ever
//     showed a date.
//
// This walks the real export rather than a fixture, so a field added to
// scripts/content/export-content-json.rb is covered the day it lands.
//
// Usage: node run-field-flow-checks.mjs <exportDir>
// Driven by scripts/test/test-exported-fields-reach-the-view.rb.

import fs from 'node:fs';
import path from 'node:path';
import { loadRuntime } from './load-runtime.mjs';

// Keys the exporter writes into a writing_index entry that a listing item is
// allowed to drop. Every entry needs a reason; an exclusion that turns out to
// survive is reported too, so the list cannot rot into a rubber stamp.
const LISTING_EXCLUSIONS = {
  xcites:
    'Cross-reference resolution reads writing_index.json directly ' +
    '(30-includes-xcite.html). A listing card never renders a citation list.'
};

const exportDir = process.argv[2];
if (!exportDir) {
  console.error('usage: run-field-flow-checks.mjs <exportDir>');
  process.exit(1);
}

// hydrateFrontMatter is internal to the runtime; 90-bootstrap.html does not
// export it, but every detail page depends on what it does.
const { runtime, internals } = loadRuntime({ expose: ['hydrateFrontMatter'] });
const hydrateFrontMatter = internals.hydrateFrontMatter;
const failures = [];
let checked = 0;

const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

// ── 1. writing_index entry → listing item ─────────────────────────────────

const entries = JSON.parse(
  fs.readFileSync(path.join(exportDir, 'data', 'writing_index.json'), 'utf8')
);
if (!Array.isArray(entries) || entries.length === 0) {
  console.error('writing_index.json is empty; nothing to check');
  process.exit(1);
}

const exportedKeys = new Set();
entries.forEach((entry) => Object.keys(entry).forEach((key) => exportedKeys.add(key)));

Object.keys(LISTING_EXCLUSIONS).forEach((key) => {
  if (!exportedKeys.has(key)) {
    failures.push(
      `exclusion list names "${key}", which the exporter no longer writes — remove it`
    );
  }
});

// One entry per key is enough to prove the whitelist covers it, but which
// entry matters: an entry whose value is empty would pass a whitelist that
// dropped the key. Prefer an entry with a populated value.
function witnessFor(key) {
  return (
    entries.find((entry) => {
      const value = entry[key];
      if (value == null || value === '') return false;
      return !(Array.isArray(value) && value.length === 0);
    }) || entries[0]
  );
}

[...exportedKeys].sort().forEach((key) => {
  checked += 1;
  const entry = witnessFor(key);
  const item = runtime.writingIndexAsListingItem(entry);
  const fm = item.front_matter || {};
  const survives = same(item[key], entry[key]) || same(fm[key], entry[key]);

  if (Object.prototype.hasOwnProperty.call(LISTING_EXCLUSIONS, key)) {
    if (survives && !same(entry[key], undefined)) {
      failures.push(
        `"${key}" is on the exclusion list but now survives into the listing item — ` +
          'delete the exclusion rather than leaving it stale'
      );
    }
    return;
  }

  if (!survives) {
    failures.push(
      `writingIndexAsListingItem drops "${key}" (exporter value ` +
        `${JSON.stringify(entry[key])} for ${entry.key || entry.slug}). ` +
        'Add it to the whitelist in _includes/content-runtime/60-fragments.html, ' +
        'or to LISTING_EXCLUSIONS here with a reason.'
    );
  }
});

// The whitelist must not invent values either: a key the exporter never wrote
// has no business appearing on a listing item.
const listingKeys = new Set();
{
  const item = runtime.writingIndexAsListingItem(entries[0]);
  Object.keys(item).forEach((key) => key !== 'front_matter' && listingKeys.add(key));
  Object.keys(item.front_matter || {}).forEach((key) => listingKeys.add(key));
}
[...listingKeys].sort().forEach((key) => {
  checked += 1;
  if (!exportedKeys.has(key)) {
    failures.push(
      `writingIndexAsListingItem reads "${key}", which no writing_index entry carries — ` +
        'the field is always undefined on a card'
    );
  }
});

// ── 2. collection payload → hydrated detail front matter ──────────────────

function collectionPayloads() {
  const root = path.join(exportDir, 'collections');
  return fs
    .readdirSync(root, { withFileTypes: true })
    .filter((dirent) => dirent.isDirectory())
    .flatMap((dirent) => {
      const dir = path.join(root, dirent.name);
      return fs
        .readdirSync(dir)
        .filter((name) => name.endsWith('.json'))
        .map((name) => ({
          label: `${dirent.name}/${name}`,
          payload: JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'))
        }));
    });
}

const payloads = collectionPayloads();
if (payloads.length === 0) {
  console.error('no exported collection objects; nothing to hydrate');
  process.exit(1);
}

let datedPayloads = 0;
payloads.forEach(({ label, payload }) => {
  const before = JSON.parse(JSON.stringify(payload.front_matter || {}));
  const hydrated = hydrateFrontMatter(JSON.parse(JSON.stringify(payload)));
  const fm = hydrated.front_matter || {};
  checked += 1;

  if (payload.date) {
    datedPayloads += 1;
    if (fm.date !== payload.date) {
      failures.push(
        `${label}: hydrateFrontMatter left front_matter.date as ${JSON.stringify(fm.date)} ` +
          `for a payload dated ${payload.date} — the detail view shows no date`
      );
    }
  }
  if (payload.last_updated && fm.last_updated !== payload.last_updated) {
    failures.push(
      `${label}: hydrateFrontMatter dropped last_updated ` +
        `(${payload.last_updated} → ${JSON.stringify(fm.last_updated)})`
    );
  }
  Object.entries(before).forEach(([key, value]) => {
    if (key === 'date' || key === 'last_updated') return;
    if (!same(fm[key], value)) {
      failures.push(
        `${label}: hydrateFrontMatter changed front_matter.${key} ` +
          `from ${JSON.stringify(value)} to ${JSON.stringify(fm[key])}`
      );
    }
  });
});

if (datedPayloads === 0) {
  failures.push('no exported payload carried a date; the date-promotion check proved nothing');
}

// Raw Markdown that has not been through the exporter still has its block
// parsed — that path is why the early return existed in the first place.
{
  checked += 1;
  const raw = hydrateFrontMatter({
    body_markdown: '---\ntitle: Raw\nlanguage: enus\n---\nBody text.\n',
    date: '2026-03-01'
  });
  const fm = raw.front_matter || {};
  if (fm.title !== 'Raw' || fm.language !== 'enus') {
    failures.push(
      `hydrateFrontMatter stopped parsing inline front matter (got ${JSON.stringify(fm)})`
    );
  }
  if (fm.date !== '2026-03-01') {
    failures.push('hydrateFrontMatter dropped the payload date when a block was parsed');
  }
  if (raw.body_markdown.trim() !== 'Body text.') {
    failures.push(`hydrateFrontMatter left the block in body_markdown: ${JSON.stringify(raw.body_markdown)}`);
  }
}

if (failures.length) {
  console.error(`Exported fields did not reach the view (${failures.length} problem(s)):`);
  failures.forEach((line) => console.error(`  - ${line}`));
  process.exit(1);
}

const excluded = Object.keys(LISTING_EXCLUSIONS);
console.log(
  `  ${exportedKeys.size} writing_index keys reach a listing item ` +
    `(${excluded.length} documented exclusion: ${excluded.join(', ')}).`
);
console.log(`  ${payloads.length} detail payloads hydrate with their dates and front matter intact.`);
console.log(`  ${checked} field-flow checks.`);
