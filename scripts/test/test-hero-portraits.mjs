#!/usr/bin/env node
// AC-HERO-06 and AC-HERO-07. Executes the functions in
// _includes/content-runtime/60-fragments.html rather than a copy of them.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const source = fs.readFileSync(
  path.join(root, '_includes/content-runtime/60-fragments.html'),
  'utf8'
);

const start = source.indexOf('function heroPortraitEntries');
const end = source.indexOf('function applyHeroPortrait(');
if (start < 0 || end < start) {
  console.error('hero portrait functions missing from 60-fragments.html');
  process.exit(1);
}

const api = new Function(
  `${source.slice(start, end)}\nreturn { heroPortraitEntries, pickHeroPortrait };`
)();

const { heroPortraitEntries, pickHeroPortrait } = api;

let failed = 0;

function check(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    failed += 1;
  }
}

function same(got, expected, message) {
  const left = JSON.stringify(got);
  const right = JSON.stringify(expected);
  check(left === right, `${message}: got ${left}, want ${right}`);
}

// AC-HERO-07
same(heroPortraitEntries(null), [], 'null payload');
same(heroPortraitEntries({ src: '/media/images/hero/a.jpg' }), [], 'object payload');
same(
  heroPortraitEntries([
    null,
    [],
    { alt: 'no src' },
    { src: '' },
    { src: '   ' },
    { src: 12 },
  ]),
  [],
  'ineligible rows'
);
same(
  heroPortraitEntries([
    { src: '  /media/images/hero/a.JPG  ' },
    { src: '/media/images/hero/b.JPG', alt: '  face  ' },
    { src: '/media/images/hero/c.JPG', alt: 4 },
    { src: '/media/images/hero/d.JPG', alt: '   ' },
  ]),
  [
    { src: '/media/images/hero/a.JPG', alt: '' },
    { src: '/media/images/hero/b.JPG', alt: 'face' },
    { src: '/media/images/hero/c.JPG', alt: '' },
    { src: '/media/images/hero/d.JPG', alt: '' },
  ],
  'normalised rows'
);

// AC-HERO-06
const two = [
  { src: '/media/images/hero/a.JPG', alt: '' },
  { src: '/media/images/hero/b.JPG', alt: 'second' },
];
check(pickHeroPortrait([], () => 0) === null, 'empty list');
check(pickHeroPortrait(null, () => 0) === null, 'null list');
same(pickHeroPortrait(two, () => 0), two[0], 'roll 0');
same(pickHeroPortrait(two, () => 0.5), two[1], 'roll 0.5');
same(pickHeroPortrait(two, () => 0.999), two[1], 'roll just below 1');
same(pickHeroPortrait(two, () => 1), two[0], 'roll 1');
same(pickHeroPortrait(two, () => -0.1), two[0], 'negative roll');
same(pickHeroPortrait(two, () => Number.NaN), two[0], 'NaN roll');
same(pickHeroPortrait(two, () => '0'), two[0], 'non-number roll');
same(pickHeroPortrait([two[0]], () => 0.999), two[0], 'single entry');

const three = two.concat([{ src: '/media/images/hero/c.JPG', alt: '' }]);
same(pickHeroPortrait(three, () => 0.4), three[1], 'roll 0.4 of three');

if (failed) {
  console.error(`hero portraits: ${failed} failure(s)`);
  process.exit(1);
}
console.log('PASS: hero portrait picker');
