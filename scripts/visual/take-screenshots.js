#!/usr/bin/env node
// take-screenshots.js — Screenshot site pages using Puppeteer for visual inspection.
//
// Usage:
//   node scripts/visual/take-screenshots.js <outputDir> <baseUrl> <pagesJsonFile>
//
// Arguments:
//   outputDir     — Directory to save screenshots (created if missing)
//   baseUrl       — Base URL of the local server (e.g. http://localhost:4000 for the
//                   public site; the workflow uses 4001 for the private CV build)
//   pagesJsonFile — Path to a flat JSON array: [{ id, name, url }, ...]
//
// Output: saves <id>.png for each page in outputDir.
//
// Exit codes:
//   0 — all screenshots successful
//   1 — one or more screenshots failed (partial output may exist)

'use strict';

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

async function main() {
  const outputDir = path.resolve(process.argv[2] || 'screenshots');
  const baseUrl = (process.argv[3] || 'http://localhost:4000').replace(/\/$/, '');
  const pagesFile = path.resolve(process.argv[4] || 'pages.json');

  const pages = JSON.parse(fs.readFileSync(pagesFile, 'utf8'));

  fs.mkdirSync(outputDir, { recursive: true });

  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  let failures = 0;

  try {
    const executing = new Set();
    const CONCURRENCY_LIMIT = 5;

    for (const pageConfig of pages) {
      const task = async () => {
        const url = `${baseUrl}${pageConfig.url}`;
        console.log(`Screenshotting: ${pageConfig.name} → ${url}`);

        const page = await browser.newPage();
        await page.setViewport({ width: 1440, height: 1200 });

        try {
          await page.goto(url, { waitUntil: 'networkidle0', timeout: 60000 });
          const outputPath = path.join(outputDir, `${pageConfig.id}.png`);
          await page.screenshot({ path: outputPath, fullPage: true });
          console.log(`  ✓ ${path.basename(outputPath)}`);
        } catch (err) {
          console.error(`  ✗ ${pageConfig.name}: ${err.message}`);
          failures += 1;
        } finally {
          await page.close();
        }
      };

      const promise = task();
      executing.add(promise);
      promise.finally(() => executing.delete(promise));

      if (executing.size >= CONCURRENCY_LIMIT) {
        await Promise.race(executing);
      }
    }

    await Promise.all(executing);
  } finally {
    await browser.close();
  }

  if (failures > 0) {
    console.error(`\n${failures} screenshot(s) failed.`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
