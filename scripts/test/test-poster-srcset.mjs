#!/usr/bin/env node
// Refs: PLT-AC-44
// Executes the real renderPosterMedia sliced out of
// _includes/content-runtime/43-blocks.html rather than a copy of it.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const utilsSource = fs.readFileSync(
  path.join(root, '_includes/content-runtime/10-utils.html'),
  'utf8'
);
const blocksSource = fs.readFileSync(
  path.join(root, '_includes/content-runtime/43-blocks.html'),
  'utf8'
);

const escStart = utilsSource.indexOf('function escapeHtml');
const escEnd = utilsSource.indexOf('function shellOrigin');
if (escStart < 0 || escEnd <= escStart) {
  console.error('FAIL test-poster-srcset: escapeHtml/escapeAttr missing from 10-utils.html');
  process.exit(1);
}
const escSlice = utilsSource.slice(escStart, escEnd);

const posterStart = blocksSource.indexOf('function renderPosterMedia');
const posterEnd = blocksSource.indexOf('function twoDigits');
if (posterStart < 0 || posterEnd <= posterStart) {
  console.error('FAIL test-poster-srcset: renderPosterMedia missing from 43-blocks.html');
  process.exit(1);
}
const posterSlice = blocksSource.slice(posterStart, posterEnd);

const renderPosterMedia = new Function(
  `${escSlice}\n${posterSlice}\nreturn renderPosterMedia;`
)();

let failed = 0;

function check(condition, message) {
  if (!condition) {
    console.error(`FAIL test-poster-srcset: ${message}`);
    failed += 1;
  }
}

function same(got, expected, message) {
  check(got === expected, `${message}: got ${JSON.stringify(got)}, want ${JSON.stringify(expected)}`);
}

// 1. Without srcset/sizes: byte-identical to today's output
const expectedPlain = [
  '<div class="ledger-poster">',
  '<img src="/media/images/covers/wide.jpg" alt="Wide Project" loading="lazy" decoding="async"',
  ' onerror="var p=this.closest(\'.ledger-poster\'); if (p) p.remove();">',
  '</div>'
].join('');

same(
  renderPosterMedia('/media/images/covers/wide.jpg', 'Wide Project'),
  expectedPlain,
  'plain image without options'
);
same(
  renderPosterMedia('/media/images/covers/wide.jpg', 'Wide Project', {}),
  expectedPlain,
  'plain image with empty options'
);
same(
  renderPosterMedia('/media/images/covers/wide.jpg', 'Wide Project', {
    srcset: '   ',
    sizes: '(min-width: 900px) 35vw, 100vw'
  }),
  expectedPlain,
  'empty srcset omits both srcset and sizes'
);

// 2. With srcset + sizes: img has src = original, srcset and sizes attributes (escaped)
const srcsetVal = '/media/images/covers/variants/wide-480.jpg 480w, /media/images/covers/variants/wide-960.jpg 960w';
const sizesVal = '(min-width: 900px) 35vw, 100vw';
const withSrcset = renderPosterMedia('/media/images/covers/wide.jpg', 'Wide "Quote"', {
  srcset: srcsetVal,
  sizes: sizesVal
});

const expectedWithSrcset = [
  '<div class="ledger-poster">',
  '<img src="/media/images/covers/wide.jpg"',
  ' srcset="/media/images/covers/variants/wide-480.jpg 480w, /media/images/covers/variants/wide-960.jpg 960w"',
  ' sizes="(min-width: 900px) 35vw, 100vw"',
  ' alt="Wide &quot;Quote&quot;" loading="lazy" decoding="async"',
  ' onerror="var p=this.closest(\'.ledger-poster\'); if (p) p.remove();">',
  '</div>'
].join('');

same(withSrcset, expectedWithSrcset, 'image with srcset and sizes');

// Escaping inside srcset and sizes
const escaped = renderPosterMedia('/media/a.jpg', 'Alt', {
  srcset: '/media/a.jpg?x=1&y="2" 480w',
  sizes: '(max-width: 600px) 100vw, "50vw"'
});
check(
  escaped.includes('srcset="/media/a.jpg?x=1&amp;y=&quot;2&quot; 480w"'),
  'srcset attribute is escaped'
);
check(
  escaped.includes('sizes="(max-width: 600px) 100vw, &quot;50vw&quot;"'),
  'sizes attribute is escaped'
);

// 3. Video URLs ignore srcset and sizes
const expectedVideo = [
  '<div class="ledger-poster">',
  '<video src="/media/clips/demo.mp4" controls preload="none" ',
  'playsinline aria-label="Demo"></video>',
  '</div>'
].join('');

same(
  renderPosterMedia('/media/clips/demo.mp4', 'Demo', {
    srcset: srcsetVal,
    sizes: sizesVal
  }),
  expectedVideo,
  'video URL ignores srcset and sizes'
);

// 4. Inspect 43-blocks.html call sites for renderSystemCard and renderProjectSpecimen
const sysCardStart = blocksSource.indexOf('function renderSystemCard');
const sysCardEnd = blocksSource.indexOf('function renderProjectLinks');
const specStart = blocksSource.indexOf('function renderProjectSpecimen');
check(sysCardStart > 0 && sysCardEnd > sysCardStart, 'renderSystemCard found in 43-blocks.html');
check(specStart > 0, 'renderProjectSpecimen found in 43-blocks.html');

const sysCardBody = blocksSource.slice(sysCardStart, sysCardEnd);
const specBody = blocksSource.slice(specStart);

check(
  sysCardBody.includes('renderPosterMedia') &&
    sysCardBody.includes('fm.thumbnail_srcset') &&
    sysCardBody.includes('sizes'),
  'renderSystemCard passes fm.thumbnail_srcset and sizes to renderPosterMedia'
);

check(
  specBody.includes('renderPosterMedia') &&
    specBody.includes('fm.thumbnail_srcset') &&
    specBody.includes('sizes'),
  'renderProjectSpecimen passes fm.thumbnail_srcset and sizes to renderPosterMedia'
);

if (failed) {
  console.error(`test-poster-srcset: ${failed} failure(s)`);
  process.exit(1);
}
console.log('PASS test-poster-srcset');
