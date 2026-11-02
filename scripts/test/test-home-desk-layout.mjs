#!/usr/bin/env node
// PLT-AC-88 / PLT-AC-98/99 / PLT-AC-104/105/106 — desk contents, hero +4pt, icon/name center, pad balance.
// Fixture links live base.css + home.css; no Jekyll build required.

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, writeFile, rm, mkdir, copyFile, readFile } from 'node:fs/promises';
import { createServer as createNetServer } from 'node:net';
import { createServer as createHttpServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join, resolve, extname } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = resolve(__dirname, '../..');
const ASSETS = join(ROOT, 'assets/css');

const VIEWPORTS = [
  { name: '390', width: 390, height: 844 },
  { name: '1024', width: 1024, height: 768 },
  { name: '1280', width: 1280, height: 800 },
  { name: '1440', width: 1440, height: 900 },
  { name: '1920', width: 1920, height: 1080 },
];

function freePort() {
  return new Promise((resolveP, reject) => {
    const server = createNetServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolveP(port));
    });
  });
}

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    '/usr/bin/google-chrome-stable',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean);
  for (const c of candidates) {
    if (c && existsSync(c)) return c;
  }
  return 'google-chrome';
}

class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.next = 1;
    this.pending = new Map();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve: res, reject: rej } = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) rej(new Error(message.error.message || JSON.stringify(message.error)));
        else res(message.result || {});
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = this.next++;
    const payload = { id, method, params };
    if (sessionId) payload.sessionId = sessionId;
    this.ws.send(JSON.stringify(payload));
    return new Promise((res, rej) => this.pending.set(id, { resolve: res, reject: rej }));
  }
}

async function openSocket(url) {
  const ws = new WebSocket(url);
  await new Promise((resolveP, reject) => {
    ws.addEventListener('open', resolveP, { once: true });
    ws.addEventListener('error', () => reject(new Error('DevTools socket failed')), { once: true });
  });
  return ws;
}

async function waitForDevtools(port, chrome) {
  let stderr = '';
  if (chrome.stderr) chrome.stderr.on('data', (c) => { stderr += c; });
  for (let i = 0; i < 100; i++) {
    if (chrome.exitCode !== null) throw new Error(`Chrome exited ${chrome.exitCode}: ${stderr.slice(-500)}`);
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (response.ok) return response.json();
    } catch (_e) { /* starting */ }
    await delay(100);
  }
  throw new Error(`Chrome DevTools did not answer on ${port}`);
}

function rowHtml(name, selected) {
  const initial = name.charAt(0).toUpperCase();
  const blurb = 'A short presentation blurb that should clamp beside the picture when the row is wide enough for both.';
  return `<button type="button" class="home-project-inventory-row group${selected ? ' is-selected' : ''}" aria-pressed="${selected ? 'true' : 'false'}" aria-label="${name}" title="${name}">
  <div class="home-project-inventory-media"><div class="ledger-poster projects-plate"><img alt="" width="1600" height="900" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="/></div><div class="home-project-inventory-mark home-project-inventory-mark--initial">${initial}</div></div>
  <div class="home-project-inventory-body">
    <div class="home-project-inventory-code"><div class="ledger-meta"><span class="code-technical home-project-inventory-index">01</span><span class="ledger-meta-sep" aria-hidden="true">/</span>Label that must not show</div></div>
    <h3 class="home-project-inventory-title card-title">${name}</h3>
    <span class="home-project-inventory-year">2026</span>
    <span class="home-project-inventory-tags">Robotics · Python</span>
    <p class="home-project-inventory-excerpt">${blurb}</p>
  </div>
  <span class="home-project-inventory-glyph material-symbols-outlined" aria-hidden="true">recycling</span>
</button>`;
}

function buildHtml() {
  const names = ['Fond de Terrasse', 'Guidelines', 'Full-stack Robotic Effector Trajectories', 'Coleta de Lixo Auxiliada por Visão Embarcada', 'Base Operating System for Sensors and Actuators'];
  const rows = names.map((n, i) => rowHtml(n, i === 0)).join('\n');
  return `<!doctype html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<link rel="stylesheet" href="/css/base.css"/>
<link rel="stylesheet" href="/css/ledger/home.css"/>
<style>
  /* Fixture shell: match live rem (~17.6px) used in desktop sim.
     Distinct title vs label stacks so the rendered gate can assert equality. */
  :root {
    --font-title: "TitleSerifFixture", Georgia, serif;
    --font-label: "LabelCapsFixture", Arial, sans-serif;
    --font-content-title: var(--font-title);
    --font-body: "BodySansFixture", Helvetica, sans-serif;
    --type-label: 0.8125rem;
    --type-body: 1.075rem;
    --type-section: 1.5rem;
    --type-section-lg: 1.75rem;
    --weight-title: 600;
    --weight-body: 300;
    --weight-display: 400;
    --color-on-surface: #111;
    --color-primary: #1c5a7a;
    --color-surface-high: rgba(0, 0, 0, 0.08);
    --color-on-surface-variant: #444;
    --border-gentle: rgba(0, 0, 0, 0.08);
    --space-xs: 0.25rem;
    --space-md: 1rem;
  }
  html { font-size: 17.6px; }
  body { margin: 0; background: #f5f5f5; color: #111; }
  /* Mirror live .theme-choice (font-body utility) for PLT-AC-88 equality gate. */
  .theme-choice {
    font-family: var(--font-body);
    font-size: var(--type-body);
    font-weight: var(--weight-body);
    letter-spacing: 0.01em;
    text-transform: none;
    line-height: 1;
  }
</style>
</head>
<body>
<button type="button" class="theme-choice" id="fixture-theme-choice">Light</button>
<main class="home-ledger">
  <section class="home-band home-band--hero">
    <div class="home-band-inner">
      <div class="home-hero">
        <div class="home-hero-portrait">
          <div class="home-hero-plate-wrap"><div class="home-hero-plate"><img alt="" width="1600" height="900" class="is-shown" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="/></div></div>
          <div class="home-hero-copy">
            <h1 class="home-hero-title"><span class="home-hero-given">Alexandre</span> <span class="home-hero-family">Loeblein Heinen</span></h1>
          </div>
        </div>
      </div>
    </div>
  </section>
  <section class="home-band" data-home-kind="portfolio" id="home-projects">
    <div class="home-band-inner">
      <header class="ledger-section-banner">
        <div class="ledger-section-lead">
          <h2 class="section-title">Projects</h2>
        </div>
      </header>
      <div class="home-projects-bench">
        <div class="home-projects-inventory-wrap">
          <div class="home-project-inventory" role="region" aria-label="Explore projects">
            ${rows}
          </div>
        </div>
        <aside class="home-project-specimen ledger-system-card">
          <figure class="home-specimen-figure">
            <div class="ledger-poster projects-plate">
              <img alt="" width="1600" height="900" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="/>
            </div>
          </figure>
        </aside>
      </div>
    </div>
  </section>
</main>
</body>
</html>`;
}

async function measure(cdp, sessionId) {
  const { result } = await cdp.send('Runtime.evaluate', {
    expression: `(() => {
      const q = (s) => document.querySelector(s);
      const qa = (s) => [...document.querySelectorAll(s)];
      const rect = (el) => {
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return { x: r.x, y: r.y, w: r.width, h: r.height };
      };
      const fs = (el) => el ? parseFloat(getComputedStyle(el).fontSize) : null;
      const bench = q('.home-projects-bench');
      const inner = q('.home-band[data-home-kind="portfolio"] .home-band-inner');
      const plate = q('.home-specimen-figure > .ledger-poster, .home-specimen-figure > .projects-plate');
      const frame = q('.home-project-inventory-row.is-selected .home-project-inventory-media');
      const rows = qa('.home-project-inventory-row');
      const hero = q('.home-hero-title');
      const band = q('.home-band[data-home-kind="portfolio"] .section-title');
      const body = q('.home-project-inventory-body');
      const benchR = rect(bench);
      const innerR = rect(inner);
      const plateR = rect(plate);
      const frameR = rect(frame);
      const gapLeft = benchR && innerR ? benchR.x - innerR.x : null;
      const gapRight = benchR && innerR ? (innerR.x + innerR.w) - (benchR.x + benchR.w) : null;
      const rowHeights = rows.map((r) => r.getBoundingClientRect().height);
      const titleCs = body ? getComputedStyle(body).display : null;
      const invTitle = q('.home-project-inventory-title');
      const drop = q('.theme-choice');
      const invCs = invTitle ? getComputedStyle(invTitle) : null;
      const dropCs = drop ? getComputedStyle(drop) : null;
      const invTitleFf = invCs ? invCs.fontFamily : null;
      const invTitleFs = invCs ? invCs.fontSize : null;
      const invTitleFw = invCs ? invCs.fontWeight : null;
      const titleWhiteSpace = invCs ? invCs.whiteSpace : null;
      const titleOverflow = invCs ? invCs.textOverflow : null;
      const dropFf = dropCs ? dropCs.fontFamily : null;
      const dropFs = dropCs ? dropCs.fontSize : null;
      const dropFw = dropCs ? dropCs.fontWeight : null;
      const bandFf = band ? getComputedStyle(band).fontFamily : null;
      const titles = qa('.home-project-inventory-title');
      const titleTrunc = titles.map((t) => ({
        text: (t.textContent || '').trim(),
        scroll: t.scrollWidth,
        client: t.clientWidth,
        truncated: t.scrollWidth > t.clientWidth + 1,
      }));
      const listWrap = q('.home-projects-inventory-wrap');
      const listR = rect(listWrap);
      const glyph = q('.home-project-inventory-row .home-project-inventory-glyph');
      const code = q('.home-project-inventory-row .home-project-inventory-code');
      const year = q('.home-project-inventory-row .home-project-inventory-year');
      const tags = q('.home-project-inventory-row .home-project-inventory-tags');
      const excerpt = q('.home-project-inventory-row.is-selected .home-project-inventory-excerpt');
      const glyphCs = glyph ? getComputedStyle(glyph) : null;
      const glyphR = glyph ? glyph.getBoundingClientRect() : null;
      const codeCs = code ? getComputedStyle(code) : null;
      const yearCs = year ? getComputedStyle(year) : null;
      const tagsCs = tags ? getComputedStyle(tags) : null;
      const excerptCs = excerpt ? getComputedStyle(excerpt) : null;
      const excerptR = excerpt ? excerpt.getBoundingClientRect() : null;
      const glyphOverflowCss = glyphCs ? (glyphCs.overflowX || glyphCs.overflow) : null;
      const glyphText = glyph ? (glyph.textContent || '').trim() : '';
      const codeLeaks = !!(code && codeCs && codeCs.display !== 'none' && codeCs.visibility !== 'hidden' && code.getBoundingClientRect().width > 0.5);
      const iconHasMetaText = /\\d{2}\\s*\\//.test(glyphText) || glyphText.indexOf('/') !== -1;
      const iconOverflow = codeLeaks || iconHasMetaText ||
        (glyphOverflowCss !== 'hidden' && glyphOverflowCss !== 'clip');
      const codeVisible = !!(code && codeCs && codeCs.display !== 'none' && codeCs.visibility !== 'hidden' && code.getBoundingClientRect().width > 0.5);
      const yearVisible = !!(year && yearCs && yearCs.display !== 'none' && yearCs.visibility !== 'hidden' && year.getBoundingClientRect().width > 0.5);
      const tagsVisible = !!(tags && tagsCs && tagsCs.display !== 'none' && tagsCs.visibility !== 'hidden' && tags.getBoundingClientRect().width > 0.5);
      let excerptLines = null;
      if (excerpt && excerptR && excerptR.height > 0 && excerptCs) {
        const lh = parseFloat(excerptCs.lineHeight) || parseFloat(excerptCs.fontSize) || 16;
        excerptLines = excerptR.height / lh;
      }
        const rowAlign = rows.map((row) => {
          const g = row.querySelector('.home-project-inventory-glyph');
          const t = row.querySelector('.home-project-inventory-title');
          if (!g || !t) return null;
          const gr = g.getBoundingClientRect();
          const tr = t.getBoundingClientRect();
          const gCy = gr.top + gr.height / 2;
          const tCy = tr.top + tr.height / 2;
          return {
            selected: row.classList.contains('is-selected'),
            name: (t.textContent || '').trim(),
            glyphCy: gCy,
            titleCy: tCy,
            delta: Math.abs(gCy - tCy),
          };
        }).filter(Boolean);
        const maxAlignDelta = rowAlign.reduce((m, r) => Math.max(m, r.delta), 0);
        const selTitle = q('.home-project-inventory-row.is-selected .home-project-inventory-title');
        const selTitleCs = selTitle ? getComputedStyle(selTitle) : null;
        const selTitleBg = selTitleCs ? selTitleCs.backgroundImage : null;
        const selRow = q('.home-project-inventory-row.is-selected');
        const selRowCs = selRow ? getComputedStyle(selRow) : null;
        const selRowBg = selRowCs ? selRowCs.backgroundColor : null;
        let padTop = null;
        let padBottom = null;
        let padDelta = null;
        let excerptPlateTopDelta = null;
        if (selRow && selTitle) {
          const rr = selRow.getBoundingClientRect();
          const glyph = selRow.querySelector('.home-project-inventory-glyph');
          const tr = selTitle.getBoundingClientRect();
          const gr = glyph ? glyph.getBoundingClientRect() : tr;
          const contentTop = Math.min(tr.top, gr.top);
          const media = selRow.querySelector('.home-project-inventory-media');
          const mediaCs = media ? getComputedStyle(media) : null;
          const mediaShown = !!(media && mediaCs && mediaCs.display !== 'none' && media.getBoundingClientRect().height > 8);
          const excerpt = selRow.querySelector('.home-project-inventory-excerpt');
          const excerptCs = excerpt ? getComputedStyle(excerpt) : null;
          const excerptShown = !!(excerpt && excerptCs && excerptCs.display !== 'none' && excerpt.getBoundingClientRect().height > 4);
          let contentBottom = Math.max(tr.bottom, gr.bottom);
          if (mediaShown) contentBottom = Math.max(contentBottom, media.getBoundingClientRect().bottom);
          if (excerptShown) contentBottom = Math.max(contentBottom, excerpt.getBoundingClientRect().bottom);
          padTop = contentTop - rr.top;
          padBottom = rr.bottom - contentBottom;
          padDelta = Math.abs(padTop - padBottom);
          if (mediaShown && excerptShown) {
            excerptPlateTopDelta = Math.abs(excerpt.getBoundingClientRect().top - media.getBoundingClientRect().top);
          }
        }
      return {
        gapLeft, gapRight,
        plate: plateR,
        frame: frameR,
        plateVarH: bench ? getComputedStyle(bench).getPropertyValue('--home-specimen-plate-height').trim() : null,
        rowHeights,
        iconBtn: bench ? getComputedStyle(bench).getPropertyValue('--home-icon-btn-size').trim() : null,
        bodyDisplay: titleCs,
        heroFs: fs(hero),
        bandFs: fs(band),
        deltaPx: (hero && band) ? fs(hero) - fs(band) : null,
        invTitleFf,
        invTitleFs,
        invTitleFw,
        titleWhiteSpace,
        titleOverflow,
        dropFf,
        dropFs,
        dropFw,
        bandFf,
        titleTrunc,
        list: listR,
        bench: benchR,
        vw: window.innerWidth,
        glyphDisplay: glyphCs ? glyphCs.display : null,
        glyphVisible: !!(glyphR && glyphR.width > 0 && glyphCs && glyphCs.display !== 'none'),
        iconOverflow,
        codeVisible,
        yearVisible,
        tagsVisible,
        excerptDisplay: excerptCs ? excerptCs.display : null,
        excerptVisible: !!(excerptR && excerptR.width > 0 && excerptR.height > 0 && excerptCs && excerptCs.display !== 'none'),
        excerptLines,
        excerptClamp: excerptCs ? excerptCs.webkitLineClamp : null,
        rowAlign,
        maxAlignDelta,
        selTitleBg,
        selRowBg,
        padTop,
        padBottom,
        padDelta,
        excerptPlateTopDelta,
      };
    })()`,
    returnByValue: true,
    awaitPromise: false,
  }, sessionId);
  return result.value;
}

function approx(a, b, tol) {
  return Math.abs(a - b) <= tol;
}

async function main() {
  const work = await mkdtemp(join(tmpdir(), 'pandorga-desk-'));
  const cssDir = join(work, 'css');
  const ledgerDir = join(cssDir, 'ledger');
  await mkdir(ledgerDir, { recursive: true });
  await copyFile(join(ASSETS, 'base.css'), join(cssDir, 'base.css'));
  await copyFile(join(ASSETS, 'ledger/home.css'), join(ledgerDir, 'home.css'));
  await writeFile(join(work, 'index.html'), buildHtml());

  const port = await freePort();
  const mime = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
  };
  const server = createHttpServer(async (req, res) => {
    const url = decodeURIComponent((req.url || '/').split('?')[0]);
    const path = url === '/' ? '/index.html' : url;
    const file = join(work, path.replace(/^\//, ''));
    if (!file.startsWith(work) || !existsSync(file)) {
      res.writeHead(404); res.end('missing'); return;
    }
    const body = await readFile(file);
    res.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream' });
    res.end(body);
  });
  await new Promise((r) => server.listen(port, '127.0.0.1', r));

  const dbgPort = await freePort();
  const chromePath = findChrome();
  const chrome = spawn(chromePath, [
    `--remote-debugging-port=${dbgPort}`,
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  const errors = [];
  try {
    const version = await waitForDevtools(dbgPort, chrome);
    const ws = await openSocket(version.webSocketDebuggerUrl);
    const cdp = new Cdp(ws);
    const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
    await cdp.send('Page.enable', {}, sessionId);
    await cdp.send('Runtime.enable', {}, sessionId);
    await cdp.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'light' }] }, sessionId);

    const baselinePlateH = 12.25 * 17.6; // rem × root

    for (const vp of VIEWPORTS) {
      await cdp.send('Emulation.setDeviceMetricsOverride', {
        width: vp.width, height: vp.height, deviceScaleFactor: 1, mobile: vp.width < 768,
      }, sessionId);
      await cdp.send('Page.navigate', { url: `http://127.0.0.1:${port}/` }, sessionId);
      await cdp.send('Page.loadEventFired', {}, sessionId).catch(() => {});
      await delay(350);
      const m = await measure(cdp, sessionId);
      if (!m) { errors.push(`${vp.name}: no metrics`); continue; }

      // Hero +4pt at 390 and 1440 (and all desks)
      if (m.deltaPx == null || m.deltaPx < 5.0 || m.deltaPx > 5.7) {
        errors.push(`${vp.name}: hero−band Δpx=${m.deltaPx} not in [5.0, 5.7] (PLT-AC-99)`);
      }

      if (vp.width >= 1024) {
        if (Math.abs(m.gapLeft) > 2 || Math.abs(m.gapRight) > 2) {
          errors.push(`${vp.name}: gaps L/R=${m.gapLeft?.toFixed?.(1)}/${m.gapRight?.toFixed?.(1)} not ~0 (PLT-AC-88)`);
        }
        if (m.bodyDisplay !== 'contents') {
          errors.push(`${vp.name}: inventory body display=${m.bodyDisplay} want contents`);
        }
        // PLT-AC-88 (2.3.20): row name face/size/weight = theme dropdown .theme-choice
        if (!m.invTitleFf || !m.dropFf || m.invTitleFf !== m.dropFf) {
          errors.push(`${vp.name}: inventory title font-family="${m.invTitleFf}" ≠ dropdown "${m.dropFf}"`);
        }
        if (!m.invTitleFw || !m.dropFw || String(m.invTitleFw) !== String(m.dropFw)) {
          errors.push(`${vp.name}: inventory title font-weight="${m.invTitleFw}" ≠ dropdown "${m.dropFw}"`);
        }
        if (m.invTitleFf && /TitleSerifFixture|LabelCapsFixture/i.test(m.invTitleFf)) {
          errors.push(`${vp.name}: inventory title is not the body face (${m.invTitleFf})`);
        }
        const fluid = vp.width * 0.022;
        const nameFs = Math.min(2.05 * 17.6, Math.max(1.45 * 17.6, fluid));
        const gotFs = parseFloat(m.invTitleFs);
        if (!Number.isFinite(gotFs) || Math.abs(gotFs - nameFs) > 1.5) {
          errors.push(`${vp.name}: name size ${m.invTitleFs} want ~${nameFs.toFixed(2)}`);
        }
        if (m.titleWhiteSpace && m.titleWhiteSpace !== 'normal') {
          errors.push(`${vp.name}: name white-space=${m.titleWhiteSpace} want normal`);
        }
        if (m.titleOverflow === 'ellipsis') {
          errors.push(`${vp.name}: name text-overflow is ellipsis`);
        }
        if (!m.rowHeights.length) {
          errors.push(`${vp.name}: no inventory rows`);
        }
        const truncated = (m.titleTrunc || []).filter((t) => t.truncated);
        if (truncated.length) {
          errors.push(`${vp.name}: truncated names ${truncated.map((t) => t.text + '(' + t.scroll + '>' + t.client + ')').join(', ')}`);
        }
        if (!m.glyphVisible) {
          errors.push(`${vp.name}: project icon glyph is not visible (PLT-AC-88)`);
        }
        if (m.iconOverflow) {
          errors.push(`${vp.name}: icon cell overflows text (PLT-AC-88)`);
        }
        if (m.codeVisible) {
          errors.push(`${vp.name}: folio/meta code is still visible (PLT-AC-88)`);
        }
        if (m.yearVisible) {
          errors.push(`${vp.name}: year is visible on contents row (PLT-AC-88)`);
        }
        if (m.tagsVisible) {
          errors.push(`${vp.name}: tags are visible on contents row (PLT-AC-88)`);
        }
        // PLT-AC-104: icon and name vertical centers within 1px on every row
        if (typeof m.maxAlignDelta !== 'number' || !m.rowAlign || !m.rowAlign.length) {
          errors.push(`${vp.name}: missing icon/name align metrics (PLT-AC-104)`);
        } else if (m.maxAlignDelta > 1) {
          const bad = m.rowAlign.filter((r) => r.delta > 1).map((r) => `${r.name}(Δ=${r.delta.toFixed(2)})`).join(', ');
          errors.push(`${vp.name}: icon/name center Δ max=${m.maxAlignDelta.toFixed(2)} > 1px (PLT-AC-104): ${bad}`);
        }
        // PLT-AC-105: gray wash on selected row; title has no mark gradient
        if (m.selTitleBg && m.selTitleBg !== 'none') {
          errors.push(`${vp.name}: selected title still has background mark (${m.selTitleBg}) (PLT-AC-105)`);
        }
        const bg = (m.selRowBg || '').replace(/\s+/g, '');
        const transparent = !bg || bg === 'transparent' || bg === 'rgba(0,0,0,0)' || bg === 'rgba(0,0,0,0.0)';
        if (transparent) {
          errors.push(`${vp.name}: selected row missing gray wash bg=${m.selRowBg} (PLT-AC-105)`);
        }
        // PLT-AC-106: top/bottom pad within 1px
        if (typeof m.padDelta !== 'number') {
          errors.push(`${vp.name}: missing selected-row pad metrics (PLT-AC-106)`);
        } else if (m.padDelta > 1) {
          errors.push(`${vp.name}: selected pad top=${m.padTop?.toFixed?.(2)} bottom=${m.padBottom?.toFixed?.(2)} Δ=${m.padDelta.toFixed(2)} > 1px (PLT-AC-106)`);
        }
        if (m.excerptVisible && typeof m.excerptPlateTopDelta === 'number' && m.excerptPlateTopDelta > 1) {
          errors.push(`${vp.name}: excerpt/plate top Δ=${m.excerptPlateTopDelta.toFixed(2)} > 1px (PLT-AC-106)`);
        }
        const frameW = 11 * 17.6;
        const frameH = frameW * 9 / 16;
        if (!m.frame || m.frame.w < 8) {
          errors.push(`${vp.name}: selected line did not open its picture`);
        } else {
          if (Math.abs(m.frame.w - frameW) > 2) {
            errors.push(`${vp.name}: picture W ${m.frame.w.toFixed(1)} want ${frameW.toFixed(1)}`);
          }
          if (Math.abs(m.frame.h - frameH) > 3) {
            errors.push(`${vp.name}: picture H ${m.frame.h.toFixed(1)} want ${frameH.toFixed(1)}`);
          }
        }
        console.log(
          `  ${vp.name}: listW=${m.list?.w?.toFixed?.(1)} rowH=${m.rowHeights?.[0]?.toFixed?.(1)} frame=${m.frame?.w?.toFixed?.(1)}×${m.frame?.h?.toFixed?.(1)} ` +
          `fs=${m.invTitleFs} truncated=${truncated.length} excerpt=${m.excerptVisible} lines=${m.excerptLines?.toFixed?.(2)} ` +
          `alignΔ=${m.maxAlignDelta?.toFixed?.(2)} padΔ=${m.padDelta?.toFixed?.(2)}`
        );
      } else {
        // Mobile: body stays hidden (icon strip), plate not +25% desk rule
        if (m.bodyDisplay && m.bodyDisplay !== 'none') {
          // On very narrow the stacked layout may still hide body — OK if none
          errors.push(`${vp.name}: expected inventory body display none on phone, got ${m.bodyDisplay}`);
        }
      }
    }

    await cdp.send('Target.closeTarget', { targetId });
    ws.close();
  } finally {
    chrome.kill('SIGKILL');
    server.close();
    await rm(work, { recursive: true, force: true });
  }

  if (errors.length) {
    console.error('FAIL test-home-desk-layout:\n' + errors.map((e) => ' - ' + e).join('\n'));
    process.exit(1);
  }
  console.log('PASS test-home-desk-layout (PLT-AC-88/98/99/104/105/106 rendered)');
}

main().catch((err) => {
  console.error('FAIL test-home-desk-layout:', err);
  process.exit(1);
});
