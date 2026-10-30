#!/usr/bin/env node
// Additive headless browser regression gate (PLT-AC-73).
// Tests home, articles list, EN article detail, PT post detail
// across 320, 390, 1440 viewports in light and dark themes.

import { spawn, execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = resolve(__dirname, '../..');
const SITE_DIR = join(ROOT, 'examples/full/_site');

function ensureSiteBuilt() {
  if (existsSync(join(SITE_DIR, 'index.html'))) return;
  console.log('Building examples/full site for regression gate...');
  execSync('ruby scripts/test/test-examples-build.rb', { cwd: ROOT, stdio: 'inherit' });
}

function freePort() {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.next = 1;
    this.pending = new Map();
    this.listeners = [];
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) reject(new Error(message.error.message || JSON.stringify(message.error)));
        else resolve(message.result || {});
        return;
      }
      if (message.method) this.listeners.forEach((listen) => listen(message));
    });
  }

  send(method, params = {}, sessionId) {
    const id = this.next++;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify(payload));
    });
  }

  once(method, sessionId) {
    return new Promise((resolve) => {
      const listen = (message) => {
        if (message.method !== method) return;
        if (sessionId && message.sessionId !== sessionId) return;
        this.listeners = this.listeners.filter((entry) => entry !== listen);
        resolve(message.params || {});
      };
      this.listeners.push(listen);
    });
  }
}

async function activePort(profile) {
  try {
    const text = await readFile(join(profile, 'DevToolsActivePort'), 'utf8');
    const value = Number(text.split('\n')[0]);
    return Number.isInteger(value) && value > 0 ? value : null;
  } catch (_error) {
    return null;
  }
}

async function waitForDevtools(port, chrome, profile) {
  let stderr = '';
  if (chrome.stderr) {
    chrome.stderr.on('data', (chunk) => { stderr += chunk; });
  }
  for (let attempt = 0; attempt < 200; attempt += 1) {
    if (chrome.exitCode !== null) {
      throw new Error(`Chrome exited ${chrome.exitCode}: ${stderr.slice(-500)}`);
    }
    const opened = await activePort(profile);
    const candidates = opened && opened !== port ? [opened, port] : [port];
    for (const candidate of candidates) {
      try {
        const response = await fetch(`http://127.0.0.1:${candidate}/json/version`);
        if (response.ok) return response.json();
      } catch (_error) {
        // Chrome is starting.
      }
    }
    await delay(100);
  }
  const opened = await activePort(profile);
  throw new Error(`Chrome DevTools did not answer on ${port}${opened ? ` (active port ${opened})` : ''}`);
}

async function openSocket(url) {
  const ws = new WebSocket(url);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', () => reject(new Error('DevTools socket failed')), { once: true });
  });
  return ws;
}

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    '/usr/bin/google-chrome-stable',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser'
  ].filter(Boolean);
  for (const c of candidates) {
    if (c && existsSync(c)) return c;
  }
  return 'google-chrome';
}

async function launchChrome() {
  const chromePath = findChrome();
  const profile = await mkdtemp(join(tmpdir(), 'pandorga-regression-'));
  const port = await freePort();
  const chrome = spawn(chromePath, [
    '--headless=new',
    '--no-sandbox',
    '--disable-gpu',
    '--disable-dev-shm-usage',
    '--no-first-run',
    '--remote-allow-origins=*',
    '--remote-debugging-address=127.0.0.1',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    'about:blank'
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  return { chrome, profile, port };
}

async function stopProcess(proc) {
  if (!proc) return;
  proc.kill('SIGKILL');
  await delay(100);
}

async function navigate(browser, sessionId, url) {
  const loaded = browser.once('Page.loadEventFired', sessionId);
  await browser.send('Page.navigate', { url }, sessionId);
  await Promise.race([
    loaded,
    delay(15000).then(() => { throw new Error(`Navigation timeout for ${url}`); })
  ]);
  await delay(250);
}

const PAGES = [
  '/',
  '/pages/articles/',
  '/articles/welcome/',
  '/posts/note/'
];

const VIEWPORTS = [
  { name: '320', width: 320, height: 700, mobile: true },
  { name: '390', width: 390, height: 844, mobile: true },
  { name: '1440', width: 1440, height: 900, mobile: false }
];

const THEMES = ['light', 'dark'];

const ASSERT_EXPRESSION = `
(function() {
  const errors = [];

  // 1. Horizontal overflow (1px tolerance)
  const root = document.documentElement;
  const body = document.body;
  const scrollWidth = Math.max(root.scrollWidth, body.scrollWidth);
  const clientWidth = root.clientWidth;
  if (scrollWidth > clientWidth + 1) {
    errors.push('Horizontal overflow: scrollWidth=' + scrollWidth + ' > clientWidth=' + clientWidth);
  }

  // 2. Home hero family right edge
  const family = document.querySelector('.home-hero-family');
  const copyCol = document.querySelector('.home-hero-copy');
  if (family && copyCol) {
    const fRect = family.getBoundingClientRect();
    const cRect = copyCol.getBoundingClientRect();
    if (fRect.right > cRect.right + 1.5) {
      errors.push('Hero family right edge (' + Math.round(fRect.right) + ') exceeds copy column (' + Math.round(cRect.right) + ')');
    }
  }

  // 3. Detail element overlaps
  const isDetail = window.location.pathname.includes('/articles/') || window.location.pathname.includes('/posts/');
  if (isDetail) {
    const title = document.querySelector('.text-detail-sidebar .text-title, .text-detail-sidebar .article-sidebar-heading h1');
    const cover = document.querySelector('.text-detail-sidebar .article-sidebar-thumbnail, .text-detail-sidebar .article-sidebar-heading figure');
    const meta = document.querySelector('.text-detail-sidebar .article-meta');
    const actions = document.querySelector('.detail-actions');
    const prose = document.querySelector('.article-content > p:first-of-type, .article-content > *');

    const detailElems = [
      { name: 'title', el: title },
      { name: 'cover', el: cover },
      { name: 'meta', el: meta },
      { name: 'actions', el: actions },
      { name: 'prose', el: prose }
    ].filter(item => item.el && item.el.getBoundingClientRect().height > 0);

    for (let i = 0; i < detailElems.length - 1; i++) {
      const curr = detailElems[i];
      const next = detailElems[i + 1];
      const rCurr = curr.el.getBoundingClientRect();
      const rNext = next.el.getBoundingClientRect();
      if (rNext.top < rCurr.bottom - 1.5) {
        errors.push('Vertical overlap: ' + next.name + ' top (' + Math.round(rNext.top) + ') < ' + curr.name + ' bottom (' + Math.round(rCurr.bottom) + ')');
      }
    }

    // 4. Progress bar position at current scroll
    const detailRoot = document.querySelector('[data-dynamic-article-detail], [data-dynamic-post-detail], [data-detail-view], .text-page-main');
    if (detailRoot) {
      const cs = window.getComputedStyle(detailRoot, '::before');
      const topVal = cs.getPropertyValue('top');
      const posVal = cs.getPropertyValue('position');
      if (posVal === 'fixed' && topVal !== '0px') {
        errors.push('Progress bar ::before top is ' + topVal + ', expected 0px (PLT-AC-72)');
      }
    }
  }

  // 5. Desktop home projects inventory logo-button stack (PLT-AC-74)
  // 6. CR-21b/c/d/e/f/g + CR-22 masthead/photo-bg/centered crops (PLT-AC-75…85)
  {
    const bench = document.querySelector('.home-projects-bench');
    const rows = document.querySelectorAll('.home-project-inventory-row');
    const rootFs = parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
    // Mobile / shared: calc(1.375rem + 2pt). Desktop (>=900): +6pt (CR-21g / PLT-AC-80).
    const expectedGlyphMobile = 1.375 * rootFs + 2 * (96 / 72);
    const expectedGlyphDesktop = 1.375 * rootFs + 6 * (96 / 72);

    if (rows.length > 0) {
      const first = rows[0];
      const glyph = first.querySelector('.home-project-inventory-glyph');
      if (glyph) {
        const gfs = parseFloat(getComputedStyle(glyph).fontSize);
        const gr = glyph.getBoundingClientRect();
        const rowH = first.getBoundingClientRect().height;
        const isInitial = glyph.classList.contains('home-project-inventory-glyph--initial');
        let expectFs = window.innerWidth >= 900 && !isInitial ? expectedGlyphDesktop : expectedGlyphMobile;
        if (isInitial) {
          const rawCard = getComputedStyle(document.documentElement).getPropertyValue('--type-card').trim();
          expectFs = parseFloat(rawCard) || expectedGlyphMobile;
          if (rawCard.endsWith('rem')) expectFs = expectFs * rootFs;
        }
        const tol = window.innerWidth >= 900 && !isInitial ? 1.0 : 1.5;
        if (Math.abs(gfs - expectFs) > tol) {
          errors.push('Inventory glyph font-size (' + gfs.toFixed(2) + 'px) not within ' + tol.toFixed(1) + 'px of expected ' + expectFs.toFixed(2) + 'px (PLT-AC-75/76/80)');
        }
        if (!isInitial && window.innerWidth >= 900 && gfs < 22) {
          errors.push('Desktop inventory icon glyph too small (' + gfs.toFixed(2) + 'px); Material Symbols inherit must not win (PLT-AC-75)');
        }
        // CR-21c: glyph fills most of the button (>= ~70% of row height)
        if (window.innerWidth >= 900 && !isInitial && gr.height + 1.5 < 0.70 * rowH) {
          errors.push('Desktop glyph height (' + gr.height.toFixed(2) + 'px) < 70% of button (' + rowH.toFixed(2) + 'px) (PLT-AC-76)');
        }
      }
      const rcs = getComputedStyle(first);
      if (Math.abs(parseFloat(rcs.borderTopWidth) - 1) > 0.5 || rcs.borderTopStyle !== 'solid') {
        errors.push('Inventory row border is ' + rcs.borderTopWidth + ' ' + rcs.borderTopStyle + ', expected 1px solid (PLT-AC-75)');
      }
    }

    if (window.innerWidth >= 900 && bench) {
      const rawSize = getComputedStyle(bench).getPropertyValue('--home-icon-btn-size').trim();
      let iconSizePx = parseFloat(rawSize);
      if (rawSize.endsWith('rem')) {
        iconSizePx = iconSizePx * rootFs;
      }

      if (rows.length > 0) {
        let firstRowWidth = null;
        rows.forEach((row, idx) => {
          const rect = row.getBoundingClientRect();
          if (idx === 0) firstRowWidth = rect.width;

          if (Math.abs(rect.width - iconSizePx) > 1.5) {
            errors.push('Row ' + idx + ' width (' + rect.width.toFixed(2) + 'px) not within 1.5px of icon size (' + iconSizePx + 'px)');
          }
          if (Math.abs(rect.height - iconSizePx) > 1.5) {
            errors.push('Row ' + idx + ' height (' + rect.height.toFixed(2) + 'px) not within 1.5px of icon size (' + iconSizePx + 'px)');
          }
          if (rect.width > iconSizePx + 8) {
            errors.push('Row ' + idx + ' width (' + rect.width.toFixed(2) + 'px) exceeds icon size + 8 (' + (iconSizePx + 8) + 'px)');
          }
        });

        const inventory = document.querySelector('.home-project-inventory');
        if (inventory && firstRowWidth !== null) {
          const invWidth = inventory.getBoundingClientRect().width;
          if (invWidth > firstRowWidth + 12) {
            errors.push('.home-project-inventory width (' + invWidth.toFixed(2) + 'px) > first row width + 12 (' + (firstRowWidth + 12).toFixed(2) + 'px)');
          }
        }
      }

      const specimen = document.querySelector('.home-project-specimen');
      if (specimen) {
        const sw = specimen.getBoundingClientRect().width;
        if (sw > 460) {
          errors.push('Specimen width (' + sw.toFixed(2) + 'px) exceeds ~plate+padding cap (~460) (PLT-AC-78)');
        }
        const plate = specimen.querySelector('.home-specimen-figure > .ledger-poster, .home-specimen-figure > .projects-plate');
        if (plate) {
          const pr = plate.getBoundingClientRect();
          const ph = pr.height;
          const pw = pr.width;
          // CR-21e: +25% vs 2.2.6 → ~215.6×383.3 (12.25rem), 16:9
          if (ph < 200 || ph > 230) {
            errors.push('Specimen plate height (' + ph.toFixed(2) + 'px) not in 200–230px band (~215.6 target) (PLT-AC-78)');
          }
          const expectW = ph * 16 / 9;
          if (Math.abs(pw - expectW) > 12 && Math.abs(pw - 383.3) > 12) {
            errors.push('Specimen plate width (' + pw.toFixed(2) + 'px) not ~16:9 of height (expect ~' + expectW.toFixed(1) + ') (PLT-AC-78)');
          }
        }

        // CR-21g / PLT-AC-80: specimen card meta, copy, chips, CTAs revert to base token size; title keeps -2pt
        {
          const pt = 2 * (96 / 72);
          const parseToken = (raw) => {
            raw = (raw || '').trim();
            let v = parseFloat(raw);
            if (!isFinite(v)) return null;
            if (raw.endsWith('rem')) v *= rootFs;
            return v;
          };
          const checks = [
            { sel: '.home-specimen-strip .ledger-meta', token: '--type-label-lg', name: 'meta', minusPt: false },
            { sel: '.home-project-specimen .home-specimen-title, .home-project-specimen .ledger-card-title', token: '--type-card-lg', name: 'title', minusPt: true },
            { sel: '.home-project-specimen .ledger-card-copy', token: '--type-body', name: 'copy', minusPt: false },
            { sel: '.home-project-specimen .ledger-chip', token: '--type-cta', name: 'chip', minusPt: false },
            { sel: '.home-specimen-foot .ledger-cta, .home-project-specimen .home-specimen-open', token: '--type-cta', name: 'foot', minusPt: false }
          ];
          const root = document.documentElement;
          checks.forEach((c) => {
            const el = document.querySelector(c.sel);
            if (!el) return;
            const base = parseToken(getComputedStyle(root).getPropertyValue(c.token));
            if (base == null) return;
            const expect = c.minusPt ? base - pt : base;
            const got = parseFloat(getComputedStyle(el).fontSize);
            if (Math.abs(got - expect) > 1.5) {
              errors.push('Specimen ' + c.name + ' font-size (' + got.toFixed(2) + 'px) not within 1.5px of ' + (c.minusPt ? 'token−2pt' : 'token base') + ' (' + expect.toFixed(2) + 'px) (PLT-AC-80)');
            }
          });
        }

        // CR-21d: column flush to card; wrap/inventory width == button width
        const wrap = document.querySelector('.home-projects-inventory-wrap');
        const inv = document.querySelector('.home-project-inventory');
        const firstRow = document.querySelector('.home-project-inventory-row');
        if (wrap && firstRow) {
          const wR = wrap.getBoundingClientRect();
          const rR = firstRow.getBoundingClientRect();
          if (Math.abs(wR.right - rR.right) > 2.5) {
            errors.push('Inventory row right (' + rR.right.toFixed(2) + ') not aligned to wrap right (' + wR.right.toFixed(2) + ') (PLT-AC-76)');
          }
          if (wR.width - rR.width > 0.5) {
            errors.push('Inventory column width (' + wR.width.toFixed(2) + ') > button width (' + rR.width.toFixed(2) + ') by >0.5px (PLT-AC-77)');
          }
          if (inv) {
            const iW = inv.getBoundingClientRect().width;
            if (iW - rR.width > 0.5) {
              errors.push('Inventory box width (' + iW.toFixed(2) + ') > button width (' + rR.width.toFixed(2) + ') by >0.5px (PLT-AC-77)');
            }
          }
          const gap = specimen.getBoundingClientRect().left - wR.right;
          if (gap > 16.5 || gap < -0.5) {
            errors.push('Column-to-card gap (' + gap.toFixed(2) + 'px) not in 0–16px (PLT-AC-77)');
          }
        }
      }
    }
  }

  // CR-21d: Explore projects label not visible at any width; aria-label on group
  {
    const label = document.querySelector('.home-projects-inventory-label');
    if (label) {
      const cs = getComputedStyle(label);
      const r = label.getBoundingClientRect();
      const hidden = cs.display === 'none' || cs.visibility === 'hidden' || cs.opacity === '0'
        || (r.width <= 1 && r.height <= 1) || cs.clip === 'rect(0px, 0px, 0px, 0px)'
        || (cs.position === 'absolute' && r.width <= 1);
      if (!hidden) {
        errors.push('Explore projects label still visible (' + r.width.toFixed(1) + 'x' + r.height.toFixed(1) + ') (PLT-AC-77)');
      }
    }
    const inv = document.querySelector('.home-project-inventory');
    if (inv) {
      const aria = (inv.getAttribute('aria-label') || '').trim().toLowerCase();
      if (aria !== 'explore projects') {
        errors.push('Inventory aria-label is "' + (inv.getAttribute('aria-label') || '') + '", expected "Explore projects" (PLT-AC-77)');
      }
    }
  }

  // CR-21d / PLT-AC-77: every home specimen / project / card poster plate is 16:9 ±1%
  {
    const plates = document.querySelectorAll(
      '.home-specimen-figure > .ledger-poster, .home-specimen-figure > .projects-plate, ' +
      '.home-card-grid .ledger-poster, .home-card-grid .projects-plate, ' +
      '.projects-page .ledger-system-card > .ledger-poster, .projects-page .ledger-system-card > .projects-plate, ' +
      '.projects-page .projects-plate--mark'
    );
    plates.forEach((el, idx) => {
      const r = el.getBoundingClientRect();
      if (r.width < 8 || r.height < 8) return;
      const ratio = r.width / r.height;
      const target = 16 / 9;
      if (Math.abs(ratio - target) / target > 0.01) {
        errors.push('Plate #' + idx + ' ratio ' + ratio.toFixed(4) + ' not within 1% of 16:9 (PLT-AC-77)');
      }
    });
  }

  // CR-21f / PLT-AC-79: dual portfolio limits + home projects subtitle ≤ block
  {
    const section = document.querySelector('.home-band[data-home-kind="portfolio"]');
    if (section) {
      const limM = (section.getAttribute('data-home-limit-mobile') || '').trim();
      const limD = (section.getAttribute('data-home-limit-desktop') || '').trim().toLowerCase();
      const mobileN = parseInt(limM, 10);
      if (!(mobileN > 0)) {
        errors.push('data-home-limit-mobile is "' + limM + '", expected positive int (default 6) (PLT-AC-79)');
      }
      if (!(limD === 'all' || limD === 'unlimited' || parseInt(limD, 10) > 0)) {
        errors.push('data-home-limit-desktop is "' + limD + '", expected all|unlimited|positive int (PLT-AC-79)');
      }

      const rows = section.querySelectorAll('.home-project-inventory-row');
      let totalProjects = 0;
      try {
        const xhr = new XMLHttpRequest();
        xhr.open('GET', '/data/writing_index.json', false);
        xhr.send(null);
        if (xhr.status >= 200 && xhr.status < 300) {
          const index = JSON.parse(xhr.responseText);
          const col = section.getAttribute('data-home-collection') || 'projects';
          totalProjects = (Array.isArray(index) ? index : []).filter(function (e) {
            return e && e.collection === col;
          }).length;
        }
      } catch (e) { /* ignore — count asserts skipped if index missing */ }

      if (totalProjects > 0 && rows.length > 0) {
        if (window.innerWidth >= 900) {
          const expectDesktop = (limD === 'all' || limD === 'unlimited')
            ? totalProjects
            : Math.min(totalProjects, parseInt(limD, 10));
          if (rows.length !== expectDesktop) {
            errors.push('Desktop inventory rows (' + rows.length + ') !== expected ' + expectDesktop + ' (PLT-AC-79)');
          }
        } else {
          const cap = mobileN > 0 ? mobileN : 6;
          if (rows.length > cap) {
            errors.push('Mobile inventory rows (' + rows.length + ') > limit_mobile ' + cap + ' (PLT-AC-79)');
          }
        }
      }

      if (window.innerWidth >= 900) {
        const note = section.querySelector('.home-section-note');
        const wrap = section.querySelector('.home-projects-inventory-wrap');
        const specimen = section.querySelector('.home-project-specimen')
          || section.querySelector('[data-home-specimen] > *')
          || section.querySelector('[data-home-specimen]');
        if (note && wrap && specimen) {
          const nR = note.getBoundingClientRect();
          const wR = wrap.getBoundingClientRect();
          const sR = specimen.getBoundingClientRect();
          if (nR.width > 8 && sR.width > 8) {
            const blockRight = Math.max(wR.right, sR.right);
            if (nR.right > blockRight + 1) {
              errors.push(
                'Home projects subtitle right (' + nR.right.toFixed(1) +
                ') past projects block right (' + blockRight.toFixed(1) + ') (PLT-AC-79)'
              );
            }
          }
        }
      }
    }
  }


  // CR-22 / CR-22.1 / PLT-AC-81…87: B3 masthead, photo-bg, name fit, contrast, 16:9 plates
  {
    const hero = document.querySelector('.home-band--hero');
    const proj = document.querySelector('.home-band[data-home-kind="portfolio"]');
    const title = document.querySelector('.home-hero-title');
    const actions = document.querySelector('.home-hero-actions');
    const plateImg = document.querySelector('.home-hero-plate img');
    const summary = document.querySelector('.home-hero-summary') || document.querySelector('.home-hero-summary p');

    function parseRgb(c) {
      if (!c) return null;
      const m = String(c).match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i);
      if (!m) return null;
      return { r: +m[1], g: +m[2], b: +m[3] };
    }
    function relLum({ r, g, b }) {
      const f = (v) => {
        v /= 255;
        return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
      };
      return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
    }

    if (hero && proj && window.innerWidth >= 1024) {
      const ledger = document.querySelector('.home-ledger');
      const lb = ledger.getBoundingClientRect();
      const mid = lb.left + lb.width / 2;
      const pb = proj.getBoundingClientRect();
      const hb = hero.getBoundingClientRect();
      const delta = Math.abs(pb.left - mid);
      if (delta > 1) {
        errors.push('Projects left (' + pb.left.toFixed(1) + ') not within 1px of content mid (' + mid.toFixed(1) + ') Δ=' + delta.toFixed(1) + ' (PLT-AC-81)');
      }
      if (hb.right > mid + 1) {
        errors.push('Hero right (' + hb.right.toFixed(1) + ') crosses content mid (' + mid.toFixed(1) + ') (PLT-AC-81)');
      }
      if (actions) {
        const ctas = [...actions.querySelectorAll(':scope > .ledger-cta, :scope > .home-hero-cta, :scope > span > .ledger-cta, :scope > span > a')];
        const ctaTops = new Set(ctas.filter(el => el.getBoundingClientRect().width > 4).map(el => Math.round(el.getBoundingClientRect().top)));
        if (ctaTops.size > 1) {
          errors.push('Hero CTAs wrap to ' + ctaTops.size + ' rows at desktop; expected one line (PLT-AC-82)');
        }
      }
      const portrait = document.querySelector('.home-hero-portrait');
      if (portrait) {
        const pcs = getComputedStyle(portrait);
        if (pcs.position !== 'absolute') {
          errors.push('Hero portrait position is ' + pcs.position + ', expected absolute background (PLT-AC-82)');
        }
      }

      // PLT-AC-86 / PLT-AC-99: name fits; h1 − band h2 in [2.4, 3.0] px
      if (title && hb.width > 40) {
        const tr = title.getBoundingClientRect();
        if (tr.right > hb.right + 1) {
          errors.push('Hero name right (' + tr.right.toFixed(1) + ') past panel right (' + hb.right.toFixed(1) + ') (PLT-AC-86)');
        }
        const band = document.querySelector('.home-band .ledger-section-banner .section-title');
        if (band) {
          const h1 = parseFloat(getComputedStyle(title).fontSize);
          const h2 = parseFloat(getComputedStyle(band).fontSize);
          const delta = h1 - h2;
          if (delta < 2.4 || delta > 3.0) {
            errors.push('Hero h1−band h2 delta ' + delta.toFixed(2) + 'px not in [2.4, 3.0] (PLT-AC-99)');
          }
        }
      }

      // PLT-AC-87: hero panel aspect near B3
      if (hb.height > 40) {
        const ratio = hb.width / hb.height;
        const expectR = window.innerWidth >= 1280 ? (637 / 693) : (454 / 736);
        if (Math.abs(ratio - expectR) / expectR > 0.08) {
          errors.push('Hero panel ratio ' + ratio.toFixed(3) + ' not within 8% of B3 ' + expectR.toFixed(3) + ' (PLT-AC-87)');
        }
      }
    }

    if (hero && window.innerWidth < 1024) {
      const hb = hero.getBoundingClientRect();
      if (Math.abs(hb.width - window.innerWidth) > 3) {
        errors.push('Stacked hero width (' + hb.width.toFixed(1) + ') != viewport (' + window.innerWidth + ') (PLT-AC-83)');
      }
      if (title) {
        const topSpace = title.getBoundingClientRect().top - hb.top;
        if (topSpace > 120) {
          errors.push('Stacked hero top spacing before name (' + topSpace.toFixed(1) + 'px) > 120px (PLT-AC-83)');
        }
      }
      if (proj) {
        const pb = proj.getBoundingClientRect();
        if (pb.top + 2 < hb.bottom) {
          errors.push('Projects not below stacked hero (PLT-AC-83)');
        }
      }
    }

    // Summary must be light on the photo (PLT-AC-86)
    if (hero && summary) {
      const col = getComputedStyle(summary).color;
      const rgb = parseRgb(col);
      if (rgb) {
        const L = relLum(rgb);
        if (L < 0.45) {
          errors.push('Hero summary color luminance ' + L.toFixed(3) + ' < 0.45 (got ' + col + '); need light text on photo (PLT-AC-86)');
        }
      }
    }

    // Centered object-position on home crops (PLT-AC-85)
    const cropImgs = document.querySelectorAll(
      '.home-hero-plate img, .home-specimen-figure .ledger-poster img, .home-featured .ledger-poster img, .home-card-grid .ledger-poster img'
    );
    cropImgs.forEach((img, idx) => {
      const op = getComputedStyle(img).objectPosition || '';
      const norm = op.trim().toLowerCase();
      const ok = norm === 'center' || norm === '50% 50%' || /^50%\s+50%$/.test(norm);
      if (!ok && img.getBoundingClientRect().width > 4) {
        errors.push('Home crop #' + idx + ' object-position is "' + op + '", expected 50% 50% (PLT-AC-85)');
      }
    });

    // Home plates (not hero bg) must be 16:9 (PLT-AC-85 / plate rule)
    const plates = document.querySelectorAll(
      '.home-specimen-figure > .ledger-poster, .home-specimen-figure > .projects-plate, .home-featured .ledger-poster, .home-card-grid .ledger-poster'
    );
    plates.forEach((el, idx) => {
      const r = el.getBoundingClientRect();
      if (r.width < 8 || r.height < 8) return;
      const ratio = r.width / r.height;
      if (Math.abs(ratio - 16 / 9) / (16 / 9) > 0.03) {
        errors.push('Home plate #' + idx + ' ratio ' + ratio.toFixed(3) + ' not 16:9 ±3% (PLT-AC-85)');
      }
    });

    // Spotlight overlay present on portrait
    if (hero) {
      const portrait = document.querySelector('.home-hero-portrait');
      if (portrait) {
        const after = getComputedStyle(portrait, '::after');
        const bg = after && after.backgroundImage;
        if (bg && bg !== 'none') {
          if (!/radial-gradient/i.test(bg)) {
            errors.push('Hero spotlight ::after missing radial-gradient (PLT-AC-84)');
          } else {
            const atMatch = bg.match(/radial-gradient\([^)]*?\bat\s+([^,\)]+)/i);
            if (atMatch) {
              const pos = atMatch[1].trim().toLowerCase().replace(/\s+/g, ' ');
              const centered = pos === '50% 50%' || pos === 'center' || pos === 'center center';
              if (!centered) {
                errors.push('Hero spotlight radial at "' + atMatch[1].trim() + '", expected 50% 50% (PLT-AC-84)');
              }
            }
          }
        }
      }
    }
  }


  return { errors };
})()
`;

async function main() {
  ensureSiteBuilt();

  const serverPort = await freePort();
  const server = spawn('python3', [
    join(ROOT, 'scripts/lighthouse_server.py'),
    String(serverPort),
    SITE_DIR
  ], { stdio: 'ignore' });

  await delay(500);

  const LAUNCH_ATTEMPTS = 3;
  let chromeStarted;
  let devtoolsVersion;

  for (let attempt = 1; attempt <= LAUNCH_ATTEMPTS; attempt += 1) {
    try {
      chromeStarted = await launchChrome();
      devtoolsVersion = await waitForDevtools(chromeStarted.port, chromeStarted.chrome, chromeStarted.profile);
      break;
    } catch (err) {
      if (chromeStarted) {
        await stopProcess(chromeStarted.chrome);
        await rm(chromeStarted.profile, { recursive: true, force: true });
      }
      if (attempt === LAUNCH_ATTEMPTS) throw err;
      console.warn(`WARN: Chrome launch attempt ${attempt} failed: ${err.message}; retrying...`);
      await delay(200);
    }
  }

  const { chrome, profile } = chromeStarted;
  let failed = false;

  try {
    const ws = await openSocket(devtoolsVersion.webSocketDebuggerUrl);
    const browser = new Cdp(ws);
    const created = await browser.send('Target.createTarget', { url: 'about:blank' });
    const attached = await browser.send('Target.attachToTarget', {
      targetId: created.targetId,
      flatten: true
    });
    const sessionId = attached.sessionId;
    await browser.send('Page.enable', {}, sessionId);
    await browser.send('Runtime.enable', {}, sessionId);

    console.log('Testing regression gate assertions across viewports, themes, and pages...');

    for (const pagePath of PAGES) {
      const targetUrl = `http://127.0.0.1:${serverPort}${pagePath}`;
      const isDetailPage = pagePath.includes('/articles/') || pagePath.includes('/posts/');

      for (const vp of VIEWPORTS) {
        await browser.send('Emulation.setDeviceMetricsOverride', {
          width: vp.width,
          height: vp.height,
          deviceScaleFactor: vp.mobile ? 2 : 1,
          mobile: vp.mobile
        }, sessionId);

        await navigate(browser, sessionId, targetUrl);

        for (const theme of THEMES) {
          await browser.send('Runtime.evaluate', {
            expression: `document.documentElement.setAttribute('data-theme', '${theme}');`
          }, sessionId);
          await delay(50);

          // Assert at scroll 0%
          const evalResult = await browser.send('Runtime.evaluate', {
            expression: ASSERT_EXPRESSION,
            returnByValue: true
          }, sessionId);

          const result = (evalResult.result && evalResult.result.value) || { errors: [] };
          if (result.errors && result.errors.length > 0) {
            console.error(`FAIL: ${pagePath} (${vp.name}px, ${theme} theme, scroll 0%):`);
            for (const err of result.errors) {
              console.error(`  - ${err}`);
            }
            failed = true;
          }

          // If detail page, re-assert progress bar at scroll 50% and 90%
          if (isDetailPage) {
            for (const pct of [0.5, 0.9]) {
              await browser.send('Runtime.evaluate', {
                expression: `window.scrollTo(0, Math.max(100, document.body.scrollHeight * ${pct}));`
              }, sessionId);
              await delay(100);

              const scrollResult = await browser.send('Runtime.evaluate', {
                expression: ASSERT_EXPRESSION,
                returnByValue: true
              }, sessionId);

              const sRes = (scrollResult.result && scrollResult.result.value) || { errors: [] };
              if (sRes.errors && sRes.errors.length > 0) {
                console.error(`FAIL: ${pagePath} (${vp.name}px, ${theme} theme, scroll ${Math.round(pct * 100)}%):`);
                for (const err of sRes.errors) {
                  console.error(`  - ${err}`);
                }
                failed = true;
              }
            }

            // Scroll back to top
            await browser.send('Runtime.evaluate', { expression: 'window.scrollTo(0, 0);' }, sessionId);
          }
        }
      }
    }

    ws.close();
  } finally {
    await stopProcess(chrome);
    await rm(profile, { recursive: true, force: true });
    await stopProcess(server);
  }

  if (failed) {
    console.error('Regression gate failed (PLT-AC-73)');
    process.exit(1);
  }

  console.log('PASS test-regression-gate (PLT-AC-73)');
}

main().catch((err) => {
  console.error(`ERROR in test-regression-gate: ${err.stack || err}`);
  process.exit(1);
});
