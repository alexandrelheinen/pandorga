#!/usr/bin/env node
// PLT-AC-47. Pure helper unit tests sliced from _includes/page/timeline-section.html
// Executes panTarget and centerPreservingScroll from source rather than a copy.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const source = fs.readFileSync(
  path.join(root, '_includes/page/timeline-section.html'),
  'utf8'
);

const start = source.indexOf('function panTarget');
const end = source.indexOf('function parseDate');
if (start < 0 || end < start) {
  console.error('FAIL: panTarget / centerPreservingScroll missing from timeline-section.html');
  process.exit(1);
}

const slice = source.slice(start, end);
if (!slice.includes('function centerPreservingScroll')) {
  console.error('FAIL: centerPreservingScroll missing from slice');
  process.exit(1);
}

const api = new Function(
  `${slice}\nreturn { panTarget, centerPreservingScroll };`
)();

const { panTarget, centerPreservingScroll } = api;

let failed = 0;

function check(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    failed += 1;
  }
}

// ── panTarget tests (PLT-AC-47) ─────────────────────────────────────────────
// Check step sizes 10% (0.1) and 90% (0.9), and clamping at both bounds (0 and maxScroll).

const visibleW = 1000;
const maxScroll = 4000;

// Step 10% right (forward in time)
check(panTarget(500, visibleW, maxScroll, 0.1) === 600, 'panTarget 10% right from 500 should be 600');
// Step 10% left (backward in time)
check(panTarget(500, visibleW, maxScroll, -0.1) === 400, 'panTarget 10% left from 500 should be 400');

// Step 90% right
check(panTarget(500, visibleW, maxScroll, 0.9) === 1400, 'panTarget 90% right from 500 should be 1400');
// Step 90% left
check(panTarget(1500, visibleW, maxScroll, -0.9) === 600, 'panTarget 90% left from 1500 should be 600');

// Lower bound clamping (scrollLeft <= 0)
check(panTarget(50, visibleW, maxScroll, -0.1) === 0, 'panTarget clamps at lower bound (10% left)');
check(panTarget(500, visibleW, maxScroll, -0.9) === 0, 'panTarget clamps at lower bound (90% left)');
check(panTarget(0, visibleW, maxScroll, -0.1) === 0, 'panTarget at 0 stays at 0');

// Upper bound clamping (scrollLeft >= maxScroll)
check(panTarget(3950, visibleW, maxScroll, 0.1) === 4000, 'panTarget clamps at upper bound (10% right)');
check(panTarget(3500, visibleW, maxScroll, 0.9) === 4000, 'panTarget clamps at upper bound (90% right)');
check(panTarget(4000, visibleW, maxScroll, 0.1) === 4000, 'panTarget at maxScroll stays at maxScroll');

// ── centerPreservingScroll tests (PLT-AC-47) ────────────────────────────────
// Center time preserved (within 1 day) across zoom factors 0.75 and 1.33.

const MS_DAY = 86400000;
const MS_YEAR = 365.25 * MS_DAY;
const LABEL_W = 96;

// Simulated timeline: 10 years of range
const minT = new Date(2015, 0, 1).getTime();
const maxT = new Date(2025, 0, 1).getTime();
const rangeMs = maxT - minT;

const initialZoomYears = 2;
const visibleChartW = visibleW - LABEL_W;
const initialChartW = visibleChartW * (rangeMs / (initialZoomYears * MS_YEAR));

function makeXPosMs(chartW) {
  return function (t) {
    return LABEL_W + ((t - minT) / rangeMs) * chartW;
  };
}

function timeFromX(x, chartW) {
  const chartX = x - LABEL_W;
  return minT + (chartX / chartW) * rangeMs;
}

// Suppose wrapper was scrolled to 1200px at 2 yr zoom
const initialScrollLeft = 1200;
const initialCenterPx = initialScrollLeft + visibleW / 2;
const centerMs = timeFromX(initialCenterPx, initialChartW);

// Zoom in: factor 0.75
const zoomInYears = initialZoomYears * 0.75;
const chartWZoomIn = visibleChartW * (rangeMs / (zoomInYears * MS_YEAR));
const maxScrollZoomIn = Math.max(0, LABEL_W + chartWZoomIn + 32 - visibleW);
const xPosMsZoomIn = makeXPosMs(chartWZoomIn);

const newScrollLeftZoomIn = centerPreservingScroll(centerMs, xPosMsZoomIn, visibleW, maxScrollZoomIn);
const newCenterPxZoomIn = newScrollLeftZoomIn + visibleW / 2;
const centerMsAfterZoomIn = timeFromX(newCenterPxZoomIn, chartWZoomIn);
const diffDaysZoomIn = Math.abs(centerMsAfterZoomIn - centerMs) / MS_DAY;

check(
  diffDaysZoomIn <= 1.0,
  `center time preserved within 1 day on zoom factor 0.75 (drift: ${diffDaysZoomIn.toFixed(3)} days)`
);

// Zoom out: factor 1.33
const zoomOutYears = initialZoomYears * 1.33;
const chartWZoomOut = visibleChartW * (rangeMs / (zoomOutYears * MS_YEAR));
const maxScrollZoomOut = Math.max(0, LABEL_W + chartWZoomOut + 32 - visibleW);
const xPosMsZoomOut = makeXPosMs(chartWZoomOut);

const newScrollLeftZoomOut = centerPreservingScroll(centerMs, xPosMsZoomOut, visibleW, maxScrollZoomOut);
const newCenterPxZoomOut = newScrollLeftZoomOut + visibleW / 2;
const centerMsAfterZoomOut = timeFromX(newCenterPxZoomOut, chartWZoomOut);
const diffDaysZoomOut = Math.abs(centerMsAfterZoomOut - centerMs) / MS_DAY;

check(
  diffDaysZoomOut <= 1.0,
  `center time preserved within 1 day on zoom factor 1.33 (drift: ${diffDaysZoomOut.toFixed(3)} days)`
);

// Clamping at lower bound
const startCenterMs = minT; // Start of timeline
const clampedStartScroll = centerPreservingScroll(startCenterMs, xPosMsZoomIn, visibleW, maxScrollZoomIn);
check(clampedStartScroll === 0, 'centerPreservingScroll clamps to 0 at timeline start');

// Clamping at upper bound
const endCenterMs = maxT; // End of timeline
const clampedEndScroll = centerPreservingScroll(endCenterMs, xPosMsZoomIn, visibleW, maxScrollZoomIn);
check(clampedEndScroll === Math.round(maxScrollZoomIn), 'centerPreservingScroll clamps to maxScroll at timeline end');

if (failed) {
  console.error(`timeline pan: ${failed} failure(s)`);
  process.exit(1);
}
console.log('PASS test-timeline-pan.mjs (PLT-AC-47)');
