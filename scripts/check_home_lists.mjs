#!/usr/bin/env node
// Load the built example home and fail when a listing band is still empty.
// The runtime fills those bands after the document loads. A score-only
// Lighthouse run treats an empty home as a fast page.

import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';

const args = process.argv.slice(2);

function flag(name) {
  const index = args.indexOf(name);
  if (index === -1 || !args[index + 1]) {
    console.error(`ERROR: missing ${name}`);
    process.exit(1);
  }
  return args[index + 1];
}

const chromePath = flag('--chrome');
const pageUrl = flag('--url');

const COUNTS = `({
  projects: document.querySelectorAll('#home-projects .home-project-inventory-row').length,
  articles: document.querySelectorAll('#home-articles .home-featured, #home-articles .ledger-card').length,
  posts: document.querySelectorAll('#home-blog .home-draft-card').length,
  projectsText: (document.querySelector('#home-projects') || {}).innerText || '',
  articlesText: (document.querySelector('#home-articles') || {}).innerText || ''
})`;

const VIEWPORTS = [
  { name: 'mobile', width: 390, height: 844, mobile: true, deviceScaleFactor: 2 },
  { name: 'desktop', width: 1280, height: 800, mobile: false, deviceScaleFactor: 1 }
];

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

async function waitForDevtools(port) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (response.ok) return response.json();
    } catch (_error) {
      // Chrome is still starting.
    }
    await delay(100);
  }
  throw new Error('Chrome DevTools did not answer');
}

async function openSocket(url) {
  const ws = new WebSocket(url);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', () => reject(new Error('DevTools socket failed')), { once: true });
  });
  return ws;
}

async function navigate(browser, sessionId, url) {
  const loaded = browser.once('Page.loadEventFired', sessionId);
  await browser.send('Page.navigate', { url }, sessionId);
  await Promise.race([
    loaded,
    delay(20000).then(() => {
      throw new Error('home did not finish loading');
    })
  ]);
}

async function counts(browser, sessionId) {
  const deadline = Date.now() + 15000;
  let last = { projects: 0, articles: 0, posts: 0, projectsText: '', articlesText: '' };
  while (Date.now() < deadline) {
    const evaluated = await browser.send('Runtime.evaluate', {
      expression: COUNTS,
      returnByValue: true
    }, sessionId);
    if (evaluated.exceptionDetails) {
      throw new Error('home list probe failed');
    }
    last = (evaluated.result && evaluated.result.value) || last;
    if (last.projects > 0 && last.articles > 0 && last.posts > 0) return last;
    await delay(200);
  }
  return last;
}

function filled(result) {
  return result.projects > 0 && result.articles > 0 && result.posts > 0;
}

async function main() {
  const profile = await mkdtemp(join(tmpdir(), 'pandorga-home-'));
  const port = await freePort();
  const chrome = spawn(chromePath, [
    '--headless=new',
    '--no-sandbox',
    '--disable-gpu',
    '--disable-dev-shm-usage',
    '--no-first-run',
    '--remote-allow-origins=*',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    'about:blank'
  ], { stdio: 'ignore' });

  let failed = false;
  try {
    const version = await waitForDevtools(port);
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

    for (const viewport of VIEWPORTS) {
      await browser.send('Emulation.setDeviceMetricsOverride', {
        width: viewport.width,
        height: viewport.height,
        deviceScaleFactor: viewport.deviceScaleFactor,
        mobile: viewport.mobile
      }, sessionId);
      await navigate(browser, sessionId, pageUrl);
      const result = await counts(browser, sessionId);
      console.log(
        `home lists (${viewport.name}): projects=${result.projects} articles=${result.articles} posts=${result.posts}`
      );
      if (!filled(result)) {
        console.error(`ERROR: ${viewport.name} home is missing project, article, or post items`);
        console.error(`projects band: ${JSON.stringify(String(result.projectsText).slice(0, 180))}`);
        console.error(`articles band: ${JSON.stringify(String(result.articlesText).slice(0, 180))}`);
        failed = true;
      }
    }
    ws.close();
  } finally {
    chrome.kill('SIGKILL');
    await delay(100);
    await rm(profile, { recursive: true, force: true });
  }

  if (failed) process.exit(1);
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exit(1);
});
