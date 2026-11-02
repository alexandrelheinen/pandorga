#!/usr/bin/env node
// PLT-AC-88 / PLT-AC-98/99 — rendered desk projects list + hero name +4pt.
// Fixture links live base.css + home.css; no Jekyll build required.

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { readFileSync } from 'node:fs';
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
  return `<button type="button" class="home-project-inventory-row group${selected ? ' is-selected' : ''}" aria-pressed="${selected ? 'true' : 'false'}" aria-label="${name}" title="${name}">
  <div class="home-project-inventory-media"><div class="home-project-inventory-mark home-project-inventory-mark--initial">${initial}</div></div>
  <div class="home-project-inventory-body"><h3 class="home-project-inventory-title card-title">${name}</h3></div>
  <span class="home-project-inventory-glyph home-project-inventory-glyph--initial" aria-hidden="true">${initial}</span>
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
          <div class="home-specimen-figure">
            <div class="ledger-poster projects-plate">
              <img alt="" width="1600" height="900" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="/>
            </div>
          </div>
          <div class="home-specimen-copy">
            <h3 class="card-title ledger-card-title home-specimen-title">Catalogue</h3>
            <p class="ledger-card-copy font-body" id="specimen-copy">A robotics library for autonomous navigation, covering spatial mapping, motion planning and trajectory tracking, with a second sentence that should not remain visible once the caption is clamped to three lines on the specimen card and a third sentence kept only to force the overflow.</p>
          </div>
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
      const rows = qa('.home-project-inventory-row');
      const hero = q('.home-hero-title');
      const band = q('.home-band[data-home-kind="portfolio"] .section-title');
      const body = q('.home-project-inventory-body');
      const benchR = rect(bench);
      const innerR = rect(inner);
      const plateR = rect(plate);
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
      const specimen = q('.home-project-specimen');
      const specR = rect(specimen);
      const copy = q('#specimen-copy');
      const copyClamp = copy ? getComputedStyle(copy).webkitLineClamp : null;
      return {
        gapLeft, gapRight,
        plate: plateR,
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
        dropFf,
        dropFs,
        dropFw,
        bandFf,
        titleTrunc,
        list: listR,
        bench: benchR,
        specimen: specR,
        copyClamp,
        vw: window.innerWidth,
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

    const homeSrc = readFileSync(join(ROOT, '_layouts/home.html'), 'utf8');
    const fnStart = homeSrc.indexOf('function ellipsizeSpecimenCopy');
    const fnEnd = homeSrc.indexOf('/* END ellipsizeSpecimenCopy */');
    if (fnStart < 0 || fnEnd < fnStart) {
      throw new Error('home.html is missing ellipsizeSpecimenCopy markers');
    }
    const ellipsizeFn = homeSrc.slice(fnStart, fnEnd);

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
        if (m.bodyDisplay !== 'flex') {
          errors.push(`${vp.name}: inventory body display=${m.bodyDisplay} want flex`);
        }
        // PLT-AC-88: index names use the serif title face, not the dropdown body face.
        if (!m.invTitleFf || !m.bandFf || m.invTitleFf !== m.bandFf) {
          errors.push(`${vp.name}: inventory title font-family="${m.invTitleFf}" ≠ band title "${m.bandFf}"`);
        }
        if (m.dropFf && m.invTitleFf === m.dropFf) {
          errors.push(`${vp.name}: inventory title still uses the dropdown face (${m.invTitleFf})`);
        }
        const wantFs = 1.02 * 17.6;
        const gotFs = parseFloat(m.invTitleFs);
        if (!Number.isFinite(gotFs) || Math.abs(gotFs - wantFs) > 0.6) {
          errors.push(`${vp.name}: inventory title font-size=${m.invTitleFs} want ~${wantFs.toFixed(2)}px`);
        }
        if (!m.rowHeights.length) {
          errors.push(`${vp.name}: no inventory rows`);
        } else {
          const h0 = m.rowHeights[0];
          for (const h of m.rowHeights) {
            if (Math.abs(h - h0) > 1.25) {
              errors.push(`${vp.name}: unequal row heights ${m.rowHeights.map((n) => n.toFixed(1)).join(',')}`);
              break;
            }
          }
          if (h0 < 32) {
            errors.push(`${vp.name}: row H ${h0} too short for an icon and a name`);
          }
        }
        // No truncation: wrapping text reports scrollWidth ≈ clientWidth.
        const truncated = (m.titleTrunc || []).filter((t) => t.truncated);
        if (truncated.length) {
          errors.push(`${vp.name}: truncated names ${truncated.map((t) => t.text + '(' + t.scroll + '>' + t.client + ')').join(', ')}`);
        }
        if (m.specimen && m.list && m.specimen.y > m.list.y + 1) {
          errors.push(`${vp.name}: specimen top ${m.specimen.y.toFixed(1)} is below the index ${m.list.y.toFixed(1)}`);
        }
        if (m.list && m.bench && m.list.w + 8 < m.bench.w * 0.9) {
          errors.push(`${vp.name}: index width ${m.list.w.toFixed(1)} is not the full bench ${m.bench.w.toFixed(1)}`);
        }
        if (String(m.copyClamp) !== '3') {
          errors.push(`${vp.name}: specimen copy line-clamp=${m.copyClamp} want 3`);
        }
        console.log(
          `  ${vp.name}: listW=${m.list?.w?.toFixed?.(1)} rowH=${m.rowHeights?.[0]?.toFixed?.(1)} ` +
          `plate=${m.plate?.w?.toFixed?.(1)}×${m.plate?.h?.toFixed?.(1)} fs=${m.invTitleFs} truncated=${truncated.length}`
        );

        // Modest 16:9 plate: floor 14.5rem, cap 17.5rem. Never the old +25% billboard.
        const floorW = 14.5 * 17.6;
        const capW = 17.5 * 17.6;
        if (!m.plate) {
          errors.push(`${vp.name}: missing specimen plate`);
        } else {
          if (m.plate.w < floorW - 2 || m.plate.w > capW + 2) {
            errors.push(`${vp.name}: plate W ${m.plate.w.toFixed(1)} outside ${floorW.toFixed(1)}–${capW.toFixed(1)}`);
          }
          const ratio = m.plate.w / m.plate.h;
          if (Math.abs(ratio - 16 / 9) > 0.04) {
            errors.push(`${vp.name}: plate aspect ${ratio.toFixed(3)} not ~16:9`);
          }
          const oldCapH = 15.3125 * 17.6;
          if (m.plate.h > oldCapH - 8) {
            errors.push(`${vp.name}: plate H ${m.plate.h.toFixed(1)} still near the +25% cap ${oldCapH.toFixed(1)}`);
          }
        }

        const ellip = await cdp.send('Runtime.evaluate', {
          expression: `(() => {
            ${ellipsizeFn}
            var copy = document.querySelector('#specimen-copy');
            if (!copy) return { error: 'missing copy' };
            var full = (copy.textContent || '').replace(/\\s+/g, ' ').trim();
            ellipsizeSpecimenCopy(copy.parentElement);
            return { full: full, text: copy.textContent || '' };
          })()`,
          returnByValue: true,
        }, sessionId);
        const fitted = ellip.result && ellip.result.value;
        if (!fitted || fitted.error) {
          errors.push(`${vp.name}: ellipsis probe failed (${fitted && fitted.error})`);
        } else if (!fitted.text.endsWith('…')) {
          errors.push(`${vp.name}: description does not end with an ellipsis: ${fitted.text.slice(-40)}`);
        } else {
          const stem = fitted.text.slice(0, -1);
          if (!fitted.full.startsWith(stem)) {
            errors.push(`${vp.name}: ellipsis stem is not a prefix of the description`);
          } else if (stem.length < fitted.full.length) {
            const next = fitted.full.charAt(stem.length);
            if (next && !/\s/.test(next) && !/[.,;:]/.test(next)) {
              errors.push(`${vp.name}: ellipsis cuts mid-word before "${next}"`);
            }
          }
        }
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
  console.log('PASS test-home-desk-layout (PLT-AC-88/98/99 rendered)');
}

main().catch((err) => {
  console.error('FAIL test-home-desk-layout:', err);
  process.exit(1);
});
