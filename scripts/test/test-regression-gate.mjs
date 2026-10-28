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
    const candidates = opened && opened !== port ? [port, opened] : [port];
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
  throw new Error(`Chrome DevTools did not answer on ${port}`);
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
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
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

    // 4. Progress bar position
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

  const { chrome, profile, port: cdpPort } = await launchChrome();
  let failed = false;

  try {
    const version = await waitForDevtools(cdpPort, chrome, profile);
    const ws = await openSocket(version.webSocketDebuggerUrl);
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

          const evalResult = await browser.send('Runtime.evaluate', {
            expression: ASSERT_EXPRESSION,
            returnByValue: true
          }, sessionId);

          const result = (evalResult.result && evalResult.result.value) || { errors: [] };
          if (result.errors && result.errors.length > 0) {
            console.error(`FAIL: ${pagePath} (${vp.name}px, ${theme} theme):`);
            for (const err of result.errors) {
              console.error(`  - ${err}`);
            }
            failed = true;
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
