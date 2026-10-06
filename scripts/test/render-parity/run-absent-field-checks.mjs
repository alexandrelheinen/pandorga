#!/usr/bin/env node
// run-absent-field-checks.mjs — the project's central invariant, executed.
//
//   An element renders only when the field backing it is present and
//   non-empty. An absent field means an absent element: never a placeholder,
//   never an em dash, never a derived stand-in, and never an empty wrapper
//   whose CSS still paints a rule or a gap.
//
// Every case below is a shape real content produces. Roughly half the corpus
// has no `language`; most posts have no `thumbnail`; `tags` arrived only with
// the redesign, so older entries have none. The build succeeds either way,
// which is exactly why this needs a test rather than an eye.
//
// Driven by scripts/test/test-absent-field-absent-element.rb.

import { loadRuntime, toHtml } from './load-runtime.mjs';
import { matchesSelector, countClass } from './selectors.mjs';

const { runtime } = loadRuntime();
const failures = [];
let checked = 0;

function record(label, problem) {
  checked += 1;
  if (problem) failures.push(`${label}: ${problem}`);
}

/** The block must render the empty string — not a wrapper, not whitespace. */
function rendersNothing(label, block, args) {
  let html;
  try {
    html = toHtml(runtime[block](...args));
  } catch (error) {
    record(label, `threw ${error.message}`);
    return;
  }
  record(label, html === '' ? null : `rendered ${JSON.stringify(html)}`);
}

/** The block renders, but must not contain the element the absent field backs. */
function omits(label, block, args, forbidden) {
  let html;
  try {
    html = toHtml(runtime[block](...args));
  } catch (error) {
    record(label, `threw ${error.message}`);
    return;
  }
  const rendered = forbidden.filter((selector) => matchesSelector(html, selector));
  record(label, rendered.length ? `rendered ${rendered.join(', ')} in ${html}` : null);
}

function separatorCount(label, parts, expected) {
  const html = toHtml(runtime.renderMetaStrip(parts));
  const actual = countClass(html, 'ledger-meta-sep');
  record(
    label,
    actual === expected ? null : `expected ${expected} separators, got ${actual} in ${html}`
  );
}

// ── language ──────────────────────────────────────────────────────────────
// Half the corpus never declared one; a neutral pill would be a lie.
[
  ['undefined', undefined],
  ['null', null],
  ['empty string', ''],
  ['whitespace', '   '],
  ['unknown code', 'de-DE'],
  ['false', false],
  ['number zero', 0]
].forEach(([shape, value]) => {
  rendersNothing(`renderLangPill / ${shape}`, 'renderLangPill', [value]);
});

// ── tags ──────────────────────────────────────────────────────────────────
// `tags` replaced `category` in the redesign, so pre-redesign entries have
// none, and a hand-edited file can leave an empty or blank-item list.
[
  ['undefined', undefined],
  ['null', null],
  ['empty array', []],
  ['array of empty strings', ['', '']],
  ['array of whitespace', ['  ', '\t']],
  ['array of nulls', [null, undefined]],
  ['not an array', 'Engineering'],
  ['empty string', '']
].forEach(([shape, value]) => {
  rendersNothing(`renderTagChips / ${shape}`, 'renderTagChips', [value]);
});

// ── thumbnail ─────────────────────────────────────────────────────────────
// Most posts have none. An empty <div class="ledger-poster"> is a bordered
// plate with nothing in it, which reads as a broken image.
[
  ['undefined', undefined],
  ['null', null],
  ['empty string', ''],
  ['whitespace', '  \n ']
].forEach(([shape, value]) => {
  rendersNothing(`renderPosterMedia / ${shape}`, 'renderPosterMedia', [value, 'Alt text']);
});

// ── url / label ───────────────────────────────────────────────────────────
// A CTA with no destination is an arrow that goes nowhere.
[
  ['no href', ['', 'Read article']],
  ['null href', [null, 'Read article']],
  ['no label', ['/articles/wsl/', '']],
  ['null label', ['/articles/wsl/', null]],
  ['neither', ['', '']]
].forEach(([shape, args]) => {
  rendersNothing(`renderCtaLink / ${shape}`, 'renderCtaLink', args);
});

// ── section banner ────────────────────────────────────────────────────────
// The title is the only required part; a kicker alone is furniture.
[
  ['no options', []],
  ['empty options', [{}]],
  ['kicker only', [{ kicker: '02' }]],
  ['note only', [{ note: '12 entries' }]],
  ['empty title', [{ title: '', kicker: '02', note: '12 entries' }]]
].forEach(([shape, args]) => {
  rendersNothing(`renderSectionBanner / ${shape}`, 'renderSectionBanner', args);
});

// Optional parts of a banner that does render must still stay absent.
omits(
  'renderSectionBanner / title only keeps kicker and note out',
  'renderSectionBanner',
  [{ title: 'Long-form inquiries' }],
  ['ledger-kicker', 'ledger-section-note']
);

// ── meta strip separators ─────────────────────────────────────────────────
// The strip is the block most exposed to the rule: it joins parts a caller
// may or may not have. A dropped part must take its slash with it, or the
// ledger line reads "02 Jan 2026 /" with nothing after the rule.
rendersNothing('renderMetaStrip / no parts', 'renderMetaStrip', [[]]);
rendersNothing('renderMetaStrip / undefined', 'renderMetaStrip', [undefined]);
rendersNothing('renderMetaStrip / all parts empty', 'renderMetaStrip', [['', null, undefined, '  ']]);
separatorCount('renderMetaStrip / one part has no separator', ['02 Jan 2026'], 0);
separatorCount('renderMetaStrip / empty trailing part drops its separator', ['02 Jan 2026', ''], 0);
separatorCount('renderMetaStrip / empty leading part drops its separator', ['', '02 Jan 2026'], 0);
separatorCount('renderMetaStrip / empty middle part drops its separator', ['a', '', 'b'], 1);
separatorCount('renderMetaStrip / null middle part drops its separator', ['a', null, 'b'], 1);
separatorCount('renderMetaStrip / three survivors take two separators', ['a', 'b', 'c'], 2);
separatorCount(
  'renderMetaStrip / mixed absences keep one separator',
  [null, 'a', '', undefined, 'b', '  '],
  1
);

// ── cards and rows: the composed case ─────────────────────────────────────
// A bare entry — title and nothing else — is what a freshly written draft
// looks like before any optional field is filled in.
const bare = { slug: 'bare-draft', front_matter: { title: 'A draft with nothing else' } };

omits(
  'renderLedgerRow / bare entry',
  'renderLedgerRow',
  [bare, { href: '/posts/bare-draft/' }],
  ['lang-pill', 'ledger-chip-row', 'ledger-chip', 'ledger-row-copy', 'ledger-meta', 'ledger-row-head']
);

omits(
  'renderLedgerRow / no cta label leaves no footer rule',
  'renderLedgerRow',
  [bare, { href: '/posts/bare-draft/' }],
  ['ledger-row-foot', 'ledger-cta']
);

omits(
  'renderArchiveCard / bare entry',
  'renderArchiveCard',
  [bare, { href: '/articles/bare-draft/' }],
  ['lang-pill', 'ledger-chip-row', 'ledger-chip', 'ledger-card-copy', 'ledger-meta', 'date-evolution']
);

omits(
  'renderArchiveCard / dates stay out of the footer unless asked',
  'renderArchiveCard',
  [
    { front_matter: { title: 'Dated', date: '2026-02-24', last_updated: '2026-08-22' } },
    { href: '/articles/dated/', ctaLabel: 'Read article' }
  ],
  ['date-evolution']
);

omits(
  'renderSystemCard / project with no media, tags, or links',
  'renderSystemCard',
  [{ front_matter: { project: 'Bossa' } }, { href: '/projects/bossa/' }],
  [
    'ledger-poster',
    'ledger-chip-row',
    'ledger-chip',
    'ledger-card-copy',
    'ledger-meta',
    'ledger-status',
    // The footer draws a rule above itself, so a project with nothing to link
    // out to must not render one. Its own page is reached from the title.
    'ledger-card-foot'
  ]
);

omits(
  'renderSystemCard / label without status renders no status chip',
  'renderSystemCard',
  [{ front_matter: { project: 'Bossa', label: 'Simulation' } }, { href: '/projects/bossa/' }],
  ['ledger-status']
);

separatorCount('renderSystemCard / label without status drops the separator', ['Simulation', ''], 0);

// PLT-AC-14: the home specimen and its rack card carry only what the project
// declares. A project that is only a name is its initial plate (PLT-AC-18)
// and a title, nothing else.
omits(
  'renderProjectSpecimen / project with no media, meta, tags, or links',
  'renderProjectSpecimen',
  [{ front_matter: { project: 'Bossa' } }, { href: '/projects/bossa/' }],
  [
    'ledger-poster',
    'material-symbols-outlined',
    'home-specimen-badge',
    'home-specimen-strip',
    'ledger-meta',
    'ledger-status',
    'ledger-card-copy',
    'ledger-chip-row',
    'ledger-card-foot'
  ]
);

omits(
  'renderProjectSpecimen / a start_date with no year renders no year',
  'renderProjectSpecimen',
  [{ front_matter: { project: 'Bossa', start_date: 'someday' } }, { href: '/projects/bossa/' }],
  ['home-specimen-strip', 'ledger-meta']
);

omits(
  'renderProjectInventoryRow / project with no index, label, status, or tagline',
  'renderProjectInventoryRow',
  [{ slug: 'bossa', front_matter: { project: 'Bossa' } }, { selectable: true }],
  [
    'home-project-inventory-code',
    'home-project-inventory-index',
    'ledger-status',
    'home-project-inventory-copy',
    'ledger-poster'
  ]
);

// The listing preview is derived from description, then excerpt, then body.
// With all three absent there is nothing to say, so there is no paragraph.
omits(
  'renderLedgerRow / no description, excerpt, or body renders no copy',
  'renderLedgerRow',
  [{ front_matter: { title: 'Silent' }, body_markdown: '' }, { href: '/posts/silent/' }],
  ['ledger-row-copy']
);

if (failures.length) {
  console.error(`Absent-field rule violated in ${failures.length} of ${checked} cases:`);
  failures.forEach((line) => console.error(`  - ${line}`));
  process.exit(1);
}

console.log(`  ${checked} absent-field cases rendered nothing, as required.`);
