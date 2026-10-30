#!/usr/bin/env node
// PLT-AC-103 — rendered monotonicity of strength (upper/face) and pool (text band)
// at 390 and 1440. Fixture uses a bright mid-tone "photo" so strength darkening
// is measurable (dark-wall regions hid the 2.3.16 charcoal inversion).

import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdtemp, writeFile, readFile, rm, mkdir } from 'node:fs/promises';
import { createServer as createNetServer } from 'node:net';
import { createServer as createHttpServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const ROOT = resolve(__dirname, '../..');
const HOME_CSS = join(ROOT, 'assets/css/ledger/home.css');

const STRENGTH_STEPS = [0.2, 0.4, 0.6, 0.8];
const POOL_STEPS = [0.2, 0.4, 0.6, 0.8];
// Minimum mean-RGB drop per 0.2 step on the bright face region / text band.
const MIN_DELTA_STRENGTH = 4.0;
const MIN_DELTA_POOL = 4.0;
const VIEWPORTS = [
  { name: '390', width: 390, height: 844, mobile: true },
  { name: '1440', width: 1440, height: 900, mobile: false }
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
    '/usr/bin/chromium-browser'
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

function extractOverlayCss(fullCss) {
  const rootIdx = fullCss.indexOf('--home-hero-vignette:');
  if (rootIdx < 0) throw new Error('missing --home-hero-vignette');
  const rootStart = fullCss.lastIndexOf(':root {', rootIdx);
  const rootEnd = fullCss.indexOf('}', rootIdx) + 1;
  const rootBlock = fullCss.slice(rootStart, rootEnd);

  const soft = fullCss.indexOf('/* Soft edgeless photo overlay');
  if (soft < 0) throw new Error('missing Soft edgeless overlay block');
  // Desk shared + ::before + ::after end at the blank line before stacked media
  const stacked = fullCss.indexOf('/* ── Stacked / full-bleed', soft);
  if (stacked < 0) throw new Error('missing stacked media marker');
  const deskBlock = fullCss.slice(soft, stacked);

  const stackMarker = fullCss.indexOf('PLT-AC-100…103: stack');
  if (stackMarker < 0) throw new Error('missing stack overlay marker');
  // Take from the stack comment through the end of the nested ::after rule
  const afterStack = fullCss.indexOf('.home-hero-portrait::after {', stackMarker);
  let depth = 0;
  let i = fullCss.indexOf('{', afterStack);
  for (; i < fullCss.length; i++) {
    if (fullCss[i] === '{') depth++;
    else if (fullCss[i] === '}') {
      depth--;
      if (depth === 0) { i++; break; }
    }
  }
  const stackRules = fullCss.slice(stackMarker, i);
  const stackMedia = `@media (max-width: 1023px) {
  ${stackRules}
}
`;

  return `${rootBlock}
${deskBlock}
${stackMedia}
`;
}

function buildFixtureHtml(overlayCss) {
  // Bright face/shirt-like mid-tone (#d4b896) so black overlays darken measurably.
  // Vertical gradient: brighter upper (face), slightly darker lower (so pool still measurable).
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
html, body { margin: 0; padding: 0; background: #111; }
.home-hero-portrait {
  position: relative;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background:
    radial-gradient(ellipse 55% 45% at 48% 32%, #e8c9a8 0%, #d4b896 40%, #b8956e 70%, #6a5a48 100%),
    linear-gradient(180deg, #c4a882 0%, #a88860 55%, #5a4a3a 100%);
}
${overlayCss}
</style>
</head>
<body>
  <div class="home-hero-portrait" id="hero"></div>
</body>
</html>`;
}

async function readPngRgba(pngPath) {
  // Minimal PNG decoder (8-bit RGB/RGBA, non-interlaced) using node:zlib.
  const { inflateSync } = await import('node:zlib');
  const buf = await readFile(pngPath);
  if (buf.toString('ascii', 1, 4) !== 'PNG') throw new Error('not PNG');
  let pos = 8;
  let width = 0, height = 0, colorType = 2, bits = 8;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos); pos += 4;
    const type = buf.toString('ascii', pos, pos + 4); pos += 4;
    const data = buf.subarray(pos, pos + len); pos += len;
    pos += 4; // crc
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bits = data[8];
      colorType = data[9];
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') break;
  }
  if (bits !== 8 || (colorType !== 2 && colorType !== 6)) {
    throw new Error(`unsupported PNG ct=${colorType} bits=${bits}`);
  }
  const bpp = colorType === 6 ? 4 : 3;
  const raw = inflateSync(Buffer.concat(idat));
  const stride = width * bpp;
  const rgba = Buffer.alloc(width * height * 4);
  let src = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[src++];
    const row = raw.subarray(src, src + stride);
    src += stride;
    const out = rgba.subarray(y * width * 4, (y + 1) * width * 4);
    // Paeth/Sub/Up/Average/None — Chrome uses filter 0 or 1 typically; handle 0–4.
    const prev = y > 0 ? rgba.subarray((y - 1) * width * 4, y * width * 4) : null;
    for (let i = 0; i < width; i++) {
      let r = row[i * bpp], g = row[i * bpp + 1], b = row[i * bpp + 2];
      const a = bpp === 4 ? row[i * bpp + 3] : 255;
      const left = i > 0 ? [out[(i - 1) * 4], out[(i - 1) * 4 + 1], out[(i - 1) * 4 + 2]] : [0, 0, 0];
      const up = prev ? [prev[i * 4], prev[i * 4 + 1], prev[i * 4 + 2]] : [0, 0, 0];
      const apply = (chan, li, ui) => {
        if (filter === 0) return chan;
        if (filter === 1) return (chan + li) & 255;
        if (filter === 2) return (chan + ui) & 255;
        if (filter === 3) return (chan + ((li + ui) >> 1)) & 255;
        if (filter === 4) {
          const p = li + ui - (prev && i > 0 ? prev[(i - 1) * 4 + (li === left[0] ? 0 : li === left[1] ? 1 : 2)] : 0);
          // Proper Paeth for each channel below
          return chan; // placeholder replaced
        }
        return chan;
      };
      if (filter === 0) {
        // none
      } else if (filter === 1) {
        r = (r + left[0]) & 255; g = (g + left[1]) & 255; b = (b + left[2]) & 255;
      } else if (filter === 2) {
        r = (r + up[0]) & 255; g = (g + up[1]) & 255; b = (b + up[2]) & 255;
      } else if (filter === 3) {
        r = (r + ((left[0] + up[0]) >> 1)) & 255;
        g = (g + ((left[1] + up[1]) >> 1)) & 255;
        b = (b + ((left[2] + up[2]) >> 1)) & 255;
      } else if (filter === 4) {
        const paeth = (a, b, c) => {
          const p = a + b - c;
          const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
          return pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
        };
        const ul = prev && i > 0 ? [prev[(i - 1) * 4], prev[(i - 1) * 4 + 1], prev[(i - 1) * 4 + 2]] : [0, 0, 0];
        r = (r + paeth(left[0], up[0], ul[0])) & 255;
        g = (g + paeth(left[1], up[1], ul[1])) & 255;
        b = (b + paeth(left[2], up[2], ul[2])) & 255;
      } else {
        throw new Error('unsupported PNG filter ' + filter);
      }
      out[i * 4] = r; out[i * 4 + 1] = g; out[i * 4 + 2] = b; out[i * 4 + 3] = a;
    }
  }
  return { width, height, rgba };
}

function meanBandsFromRgba({ width, height, rgba }, faceY0, faceY1, faceX0, faceX1, textY0, textY1) {
  const band = (y0, y1, x0 = 0, x1 = 1) => {
    const ya = Math.floor(height * y0);
    const yb = Math.max(ya + 1, Math.floor(height * y1));
    const xa = Math.floor(width * x0);
    const xb = Math.max(xa + 1, Math.floor(width * x1));
    let s = 0, n = 0, pb = 0;
    for (let y = ya; y < yb; y++) {
      for (let x = xa; x < xb; x++) {
        const i = (y * width + x) * 4;
        const r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
        s += (r + g + b) / 3;
        n++;
        if (r + g + b < 3) pb++;
      }
    }
    return { mean: n ? s / n : 0, pb: n ? (100 * pb) / n : 0 };
  };
  const face = band(faceY0, faceY1, faceX0, faceX1);
  const text = band(textY0, textY1);
  return { face: face.mean, text: text.mean, pb: text.pb };
}

async function main() {
  const fullCss = await readFile(HOME_CSS, 'utf8');
  const overlayCss = extractOverlayCss(fullCss);
  const html = buildFixtureHtml(overlayCss);

  const work = await mkdtemp(join(tmpdir(), 'pandorga-mono-'));
  const htmlPath = join(work, 'index.html');
  await writeFile(htmlPath, html);

  const httpPort = await freePort();
  const httpServer = createHttpServer(async (req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
  });
  await new Promise((r) => httpServer.listen(httpPort, '127.0.0.1', r));

  const chromePath = findChrome();
  const profile = await mkdtemp(join(tmpdir(), 'pandorga-mono-chrome-'));
  const dbgPort = await freePort();
  const chrome = spawn(chromePath, [
    '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
    '--no-first-run', '--remote-allow-origins=*',
    '--remote-debugging-address=127.0.0.1',
    `--remote-debugging-port=${dbgPort}`,
    `--user-data-dir=${profile}`,
    'about:blank'
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  const errors = [];
  try {
    const version = await waitForDevtools(dbgPort, chrome);
    const ws = await openSocket(version.webSocketDebuggerUrl);
    const browser = new Cdp(ws);

    const { targetId } = await browser.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await browser.send('Target.attachToTarget', { targetId, flatten: true });
    await browser.send('Page.enable', {}, sessionId);
    await browser.send('Runtime.enable', {}, sessionId);

    for (const vp of VIEWPORTS) {
      await browser.send('Emulation.setDeviceMetricsOverride', {
        width: vp.width, height: vp.height,
        deviceScaleFactor: 1, mobile: vp.mobile
      }, sessionId);

      await browser.send('Page.navigate', { url: `http://127.0.0.1:${httpPort}/` }, sessionId);
      await delay(400);

      // --- Strength monotonicity (pool fixed mid) ---
      const strengthFace = [];
      for (const s of STRENGTH_STEPS) {
        await browser.send('Runtime.evaluate', {
          expression: `document.documentElement.style.setProperty('--home-hero-vignette','${s}');document.documentElement.style.setProperty('--home-hero-pool','0.50');`
        }, sessionId);
        await delay(120);
        const shot = await browser.send('Page.captureScreenshot', { format: 'png' }, sessionId);
        const pngPath = join(work, `s-${vp.name}-${s}.png`);
        await writeFile(pngPath, Buffer.from(shot.data, 'base64'));
        // Face/shirt: central-upper bright region (not dark edges)
        const m = meanBandsFromRgba(await readPngRgba(pngPath), 0.12, 0.38, 0.30, 0.70, 0.62, 0.92);
        strengthFace.push(m.face);
        console.log(`strength ${s} @${vp.name}: face=${m.face.toFixed(1)} text=${m.text.toFixed(1)}`);
      }
      for (let i = 1; i < strengthFace.length; i++) {
        const delta = strengthFace[i - 1] - strengthFace[i];
        if (delta < MIN_DELTA_STRENGTH) {
          errors.push(`${vp.name}: strength ${STRENGTH_STEPS[i - 1]}→${STRENGTH_STEPS[i]} face brightness drop ${delta.toFixed(2)} < ${MIN_DELTA_STRENGTH} (PLT-AC-103)`);
        }
      }

      // --- Pool monotonicity (strength fixed mid) ---
      const poolText = [];
      let maxPb = 0;
      for (const p of POOL_STEPS) {
        await browser.send('Runtime.evaluate', {
          expression: `document.documentElement.style.setProperty('--home-hero-vignette','0.50');document.documentElement.style.setProperty('--home-hero-pool','${p}');`
        }, sessionId);
        await delay(120);
        const shot = await browser.send('Page.captureScreenshot', { format: 'png' }, sessionId);
        const pngPath = join(work, `p-${vp.name}-${p}.png`);
        await writeFile(pngPath, Buffer.from(shot.data, 'base64'));
        const m = meanBandsFromRgba(await readPngRgba(pngPath), 0.12, 0.38, 0.30, 0.70, 0.62, 0.92);
        poolText.push(m.text);
        maxPb = Math.max(maxPb, m.pb);
        console.log(`pool ${p} @${vp.name}: face=${m.face.toFixed(1)} text=${m.text.toFixed(1)} pb%=${m.pb.toFixed(2)}`);
      }
      for (let i = 1; i < poolText.length; i++) {
        const delta = poolText[i - 1] - poolText[i];
        if (delta < MIN_DELTA_POOL) {
          errors.push(`${vp.name}: pool ${POOL_STEPS[i - 1]}→${POOL_STEPS[i]} text brightness drop ${delta.toFixed(2)} < ${MIN_DELTA_POOL} (PLT-AC-103)`);
        }
      }
      if (maxPb > 0.01) {
        errors.push(`${vp.name}: pure-black pixels in text band ${maxPb.toFixed(3)}% > 0 (PLT-AC-103)`);
      }

      // --- Independence: strength change must not move text band much; pool must not move face much ---
      await browser.send('Runtime.evaluate', {
        expression: `document.documentElement.style.setProperty('--home-hero-vignette','0.20');document.documentElement.style.setProperty('--home-hero-pool','0.80');`
      }, sessionId);
      await delay(120);
      let shot = await browser.send('Page.captureScreenshot', { format: 'png' }, sessionId);
      let pngPath = join(work, `ind-a-${vp.name}.png`);
      await writeFile(pngPath, Buffer.from(shot.data, 'base64'));
      const a = meanBandsFromRgba(await readPngRgba(pngPath), 0.12, 0.38, 0.30, 0.70, 0.62, 0.92);

      await browser.send('Runtime.evaluate', {
        expression: `document.documentElement.style.setProperty('--home-hero-vignette','0.80');document.documentElement.style.setProperty('--home-hero-pool','0.80');`
      }, sessionId);
      await delay(120);
      shot = await browser.send('Page.captureScreenshot', { format: 'png' }, sessionId);
      pngPath = join(work, `ind-b-${vp.name}.png`);
      await writeFile(pngPath, Buffer.from(shot.data, 'base64'));
      const b = meanBandsFromRgba(await readPngRgba(pngPath), 0.12, 0.38, 0.30, 0.70, 0.62, 0.92);

      // Strength ↑ should darken face substantially; text band change should be small (mask)
      if (a.face - b.face < MIN_DELTA_STRENGTH * 2) {
        errors.push(`${vp.name}: independence strength 0.2→0.8 face drop ${(a.face - b.face).toFixed(2)} too small (PLT-AC-103)`);
      }
      if (Math.abs(a.text - b.text) > 6.0) {
        errors.push(`${vp.name}: independence: strength change moved text band by ${Math.abs(a.text - b.text).toFixed(2)} (>6) (PLT-AC-103)`);
      }

      await browser.send('Runtime.evaluate', {
        expression: `document.documentElement.style.setProperty('--home-hero-vignette','0.70');document.documentElement.style.setProperty('--home-hero-pool','0.20');`
      }, sessionId);
      await delay(120);
      shot = await browser.send('Page.captureScreenshot', { format: 'png' }, sessionId);
      pngPath = join(work, `ind-c-${vp.name}.png`);
      await writeFile(pngPath, Buffer.from(shot.data, 'base64'));
      const c = meanBandsFromRgba(await readPngRgba(pngPath), 0.12, 0.38, 0.30, 0.70, 0.62, 0.92);

      await browser.send('Runtime.evaluate', {
        expression: `document.documentElement.style.setProperty('--home-hero-vignette','0.70');document.documentElement.style.setProperty('--home-hero-pool','0.80');`
      }, sessionId);
      await delay(120);
      shot = await browser.send('Page.captureScreenshot', { format: 'png' }, sessionId);
      pngPath = join(work, `ind-d-${vp.name}.png`);
      await writeFile(pngPath, Buffer.from(shot.data, 'base64'));
      const d = meanBandsFromRgba(await readPngRgba(pngPath), 0.12, 0.38, 0.30, 0.70, 0.62, 0.92);

      if (c.text - d.text < MIN_DELTA_POOL * 2) {
        errors.push(`${vp.name}: independence pool 0.2→0.8 text drop ${(c.text - d.text).toFixed(2)} too small (PLT-AC-103)`);
      }
      if (Math.abs(c.face - d.face) > 6.0) {
        errors.push(`${vp.name}: independence: pool change moved face by ${Math.abs(c.face - d.face).toFixed(2)} (>6) (PLT-AC-103)`);
      }
    }

    ws.close();
  } finally {
    chrome.kill('SIGKILL');
    httpServer.close();
    await delay(100);
    await rm(profile, { recursive: true, force: true });
    await rm(work, { recursive: true, force: true });
  }

  if (errors.length) {
    console.error('FAIL test-home-hero-overlay-monotonic (PLT-AC-103):');
    for (const e of errors) console.error('  - ' + e);
    process.exit(1);
  }
  console.log('PASS test-home-hero-overlay-monotonic (PLT-AC-103)');
}

main().catch((err) => {
  console.error(`ERROR: ${err.stack || err}`);
  process.exit(1);
});
