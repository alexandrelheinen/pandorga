#!/usr/bin/env node
/**
 * Unit checks for display-math row-break normalization.
 * See scripts/lib/normalize-display-math.mjs and docs/content/elements.md.
 */
import { normalizeDisplayMathTex, normalizeMathRegion } from '../lib/normalize-display-math.mjs';

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    console.error(`FAIL: ${label}`);
    console.error('  expected:', JSON.stringify(expected));
    console.error('  actual:  ', JSON.stringify(actual));
    process.exit(1);
  }
  console.log(`  ok: ${label}`);
}

console.log('Testing display-math row-break normalization...');

const alignBroken = [
  '\\begin{align}',
  'p(x) &= \\int p(x,y)\\mathrm{d}y \\',
  'p(y|x) &= \\frac{p(x,y)}{p(x)} \\',
  'p(x|y) &= \\frac{p(y|x)p(x)}{p(y)}',
  '\\end{align}',
].join('\n');

const alignFixed = [
  '\\begin{align}',
  'p(x) &= \\int p(x,y)\\mathrm{d}y \\\\',
  'p(y|x) &= \\frac{p(x,y)}{p(x)} \\\\',
  'p(x|y) &= \\frac{p(y|x)p(x)}{p(y)}',
  '\\end{align}',
].join('\n');

assertEqual(
  normalizeDisplayMathTex(alignBroken),
  alignFixed,
  'align trailing single backslash → \\\\'
);

assertEqual(
  normalizeDisplayMathTex('\\begin{bmatrix}x-x_r\\ y-y_r\\end{bmatrix}'),
  '\\begin{bmatrix}x-x_r\\\\ y-y_r\\end{bmatrix}',
  'bmatrix mid-line \\ + space → \\\\'
);

const alignedOk = [
  '\\begin{aligned}',
  'a &= 1 \\\\',
  'b &= 2',
  '\\end{aligned}',
].join('\n');

assertEqual(
  normalizeDisplayMathTex(alignedOk),
  alignedOk,
  'already-correct \\\\ left unchanged'
);

assertEqual(
  normalizeDisplayMathTex('a = b\\,c\\;d'),
  'a = b\\,c\\;d',
  'spacing commands \\, and \\; untouched outside row envs'
);

assertEqual(
  normalizeMathRegion('$$\\begin{align}a &= 1 \\ b &= 2\\end{align}$$'),
  '$$\\begin{align}a &= 1 \\\\ b &= 2\\end{align}$$',
  '$$ region wrapper preserved'
);

assertEqual(
  normalizeMathRegion('$a\\\\b$'),
  '$a\\\\b$',
  'inline math not normalized'
);

console.log('All display-math row-break tests passed.');
