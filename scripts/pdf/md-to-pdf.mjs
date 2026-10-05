#!/usr/bin/env node
/**
 * md-to-pdf.mjs — Render editorial Markdown (articles, posts, …) to a shareable A4 PDF.
 *
 * Usage:
 *   node scripts/pdf/md-to-pdf.mjs -i <input.md> -o <output.pdf>
 *
 * Spec: docs/features/markdown-pdf.md
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import yaml from 'js-yaml';
import puppeteer from 'puppeteer';
import { normalizeMathRegion } from '../lib/normalize-display-math.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');

function usage(exitCode = 1) {
  console.error('Usage: node scripts/pdf/md-to-pdf.mjs -i <input.md> -o <output.pdf>');
  process.exit(exitCode);
}

function parseArgs(argv) {
  const args = { input: null, output: null };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '-i' || a === '--input') {
      args.input = argv[++i];
    } else if (a === '-o' || a === '--output') {
      args.output = argv[++i];
    } else if (a === '-h' || a === '--help') {
      usage(0);
    } else {
      console.error(`Unknown argument: ${a}`);
      usage(1);
    }
  }
  if (!args.input || !args.output) usage(1);
  return args;
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/'/g, '&#39;');
}

// Same delimiters as kramdown's MathJax config (_config.yml) — see docs/content/elements.md.
function containsMathMarkup(markdown) {
  const text = String(markdown || '');
  if (/\$\$[\s\S]+?\$\$/.test(text)) return true;
  if (/\\\([\s\S]+?\\\)/.test(text)) return true;
  if (/\\\[[\s\S]+?\\\]/.test(text)) return true;
  // Inline `$...$`, mirroring MathJax's own rule: no whitespace touching the delimiters.
  if (/\$[^\s$](?:[^$]*?[^\s$])?\$/.test(text)) return true;
  return false;
}

// marked/CommonMark would otherwise mangle LaTeX inside math regions: backslash
// escapes strip `\,`, `\{`, and turn a `\\` row break into a hard `<br>`;
// underscores and asterisks can be read as emphasis (`x_i`, `a*b`). Pulling the
// whole region out into an opaque placeholder before marked.parse — and putting
// the original text back (HTML-escaped) afterwards — sidesteps all of that
// instead of trying to out-guess Markdown's escaping rules. Code spans/fences
// are left untouched.
const MATH_REGION_PATTERN = /\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\]|\\\([\s\S]+?\\\)|\$[^\s$](?:[^$]*?[^\s$])?\$/g;
const MATH_PLACEHOLDER_PREFIX = '\uE000MDPDFMATH';
const MATH_PLACEHOLDER_SUFFIX = '\uE001';

function extractMathRegions(markdown, mathRegistry) {
  const text = String(markdown || '');
  const segments = text.split(/(```[\s\S]*?```|`[^`\n]*`)/g);
  return segments
    .map((segment, i) => {
      if (i % 2 === 1) return segment;
      return segment.replace(MATH_REGION_PATTERN, (mathMatch) => {
        const index = mathRegistry.length;
        // Same row-break repair as the browser content runtime.
        mathRegistry.push(normalizeMathRegion(mathMatch));
        return `${MATH_PLACEHOLDER_PREFIX}${index}${MATH_PLACEHOLDER_SUFFIX}`;
      });
    })
    .join('');
}

function restoreMathRegions(html, mathRegistry) {
  let result = String(html || '');
  mathRegistry.forEach((mathText, index) => {
    result = result.split(`${MATH_PLACEHOLDER_PREFIX}${index}${MATH_PLACEHOLDER_SUFFIX}`).join(escapeHtml(mathText));
  });
  return result;
}

function parseIncludeAttrs(raw) {
  const attrs = {};
  let text = String(raw || '');
  text = text.replace(/([\w-]+)\s*=\s*(?:"([\s\S]*?)"|'([\s\S]*?)')/g, (_, key, dbl, sgl) => {
    attrs[key] = dbl != null ? dbl : sgl;
    return '';
  });
  text.replace(/([\w-]+)\s*=\s*([^\s]+)/g, (_, key, val) => {
    if (!(key in attrs)) attrs[key] = val;
    return '';
  });
  return attrs;
}

function unwrapMediaSrc(path) {
  const value = String(path == null ? '' : path).trim();
  if (!value) return '';
  const md = value.match(/^\[([^\]]*)\]\(([^)\s]+)\)\s*$/);
  if (md) return String(md[2] || '').trim();
  const angle = value.match(/^<([^>\s]+)>\s*$/);
  if (angle) return String(angle[1] || '').trim();
  return value;
}

function cutInHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return '';
  const sideClass = attrs.side === 'right' ? ' article-cut-in--right' : '';
  return `<img class="article-cut-in${sideClass}" src="${escapeAttr(src)}" alt="${escapeAttr(attrs.alt || '')}" width="120" loading="lazy">`;
}

function figureHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return '';
  const caption = attrs.caption || '';
  const source = attrs.source || '';
  const width = attrs.width ? `max-width:${escapeAttr(attrs.width)}%;` : 'max-width:100%;';
  const capParts = [];
  if (caption) capParts.push(escapeHtml(caption));
  if (source) capParts.push(`Source: ${escapeHtml(source)}`);
  return [
    `<figure class="pdf-figure" style="${width}">`,
    `<img src="${escapeAttr(src)}" alt="${escapeAttr(attrs.alt || caption || 'Figure')}" loading="lazy">`,
    capParts.length ? `<figcaption>${capParts.join(' | ')}</figcaption>` : '',
    '</figure>',
  ].join('');
}

function mediaNoteHtml(label, url) {
  const href = url ? `<a href="${escapeAttr(url)}">${escapeHtml(url)}</a>` : '';
  return `<aside class="pdf-media-note"><strong>${escapeHtml(label)}</strong>${href ? ` | ${href}` : ''}</aside>`;
}

// A readable substitute for embeds that cannot play in a static PDF: a linked
// thumbnail (when one exists) plus a plain "go watch it" link, no mention of
// what got "omitted" — the reader just wants to know where to watch it.
function mediaWatchCardHtml({ thumbSrc, watchUrl, title, caption, linkLabel }) {
  const titleHtml = title ? `<strong>${escapeHtml(title)}</strong>` : '';
  const captionHtml = caption ? `<span class="pdf-media-desc">${escapeHtml(caption)}</span>` : '';
  const label = escapeHtml(linkLabel || 'Watch the video');
  const thumbHtml = thumbSrc
    ? [
        `<a class="pdf-media-thumb-link" href="${escapeAttr(watchUrl)}">`,
        `<img src="${escapeAttr(thumbSrc)}" alt="${escapeAttr(title || label)}">`,
        '<span class="pdf-media-play">&#9658;</span>',
        '</a>',
      ].join('')
    : '<div class="pdf-media-noimg"><span class="pdf-media-play">&#9658;</span></div>';
  return [
    '<div class="pdf-media-card">',
    thumbHtml,
    '<div class="pdf-media-caption">',
    titleHtml,
    captionHtml,
    `<a href="${escapeAttr(watchUrl)}">${label} &#8599;</a>`,
    '</div>',
    '</div>',
  ].join('');
}

function youtubeWatchUrl(id) {
  return `https://www.youtube.com/watch?v=${id}`;
}

function youtubeThumbnailUrl(id) {
  return `https://img.youtube.com/vi/${id}/hqdefault.jpg`;
}

const youtubeTitleCache = new Map();

// Best-effort: the noembed/oEmbed title makes the card useful even without a
// caption. A failed or slow lookup just falls back to a generic label.
async function fetchYoutubeTitle(id) {
  if (youtubeTitleCache.has(id)) return youtubeTitleCache.get(id);
  const promise = (async () => {
    try {
      const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(youtubeWatchUrl(id))}&format=json`;
      const res = await fetch(oembedUrl, { signal: AbortSignal.timeout(8000) });
      if (!res.ok) return null;
      const data = await res.json();
      return typeof data.title === 'string' ? data.title : null;
    } catch (err) {
      console.warn(`Could not fetch YouTube title for ${id}: ${err.message}`);
      return null;
    }
  })();
  youtubeTitleCache.set(id, promise);
  return promise;
}

function youtubePlaceholder(index) {
  return `<div class="pdf-youtube-placeholder" data-youtube-id="${index}"></div>`;
}

function registerYoutubeCard(registry, { id, caption, isShort }) {
  if (!id) return '';
  const index = registry.length;
  registry.push({ index, id, caption, isShort });
  return youtubePlaceholder(index);
}

async function resolveYoutubeCard(entry) {
  const title = await fetchYoutubeTitle(entry.id);
  return mediaWatchCardHtml({
    thumbSrc: youtubeThumbnailUrl(entry.id),
    watchUrl: youtubeWatchUrl(entry.id),
    title,
    caption: entry.caption,
    linkLabel: entry.isShort ? 'Watch the Short on YouTube' : 'Watch on YouTube',
  });
}

async function resolveYoutubePlaceholders(bodyHtml, registry) {
  const replacements = await Promise.all(registry.map(resolveYoutubeCard));
  let html = bodyHtml;
  registry.forEach((entry, i) => {
    html = html.replace(youtubePlaceholder(entry.index), replacements[i]);
  });
  return html;
}

function videoHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return '';
  const caption = attrs.caption || '';
  return mediaWatchCardHtml({
    thumbSrc: null,
    watchUrl: src,
    title: caption || null,
    caption: '',
    linkLabel: 'Watch the video',
  });
}

function plotlyPlaceholder(index) {
  return `<div class="pdf-plotly-placeholder" data-plotly-id="${index}"></div>`;
}

function plotlyFallbackHtml(attrs) {
  const src = attrs.src || '(no path)';
  return mediaNoteHtml('Interactive Plotly chart omitted in PDF', src);
}

function plotlySnapshotHtml(attrs, dataUri) {
  const caption = attrs.caption || '';
  const source = attrs.source || '';
  const width = attrs.width ? `max-width:${escapeAttr(attrs.width)}%;` : 'max-width:100%;';
  const capParts = [];
  if (caption) capParts.push(escapeHtml(caption));
  if (source) capParts.push(`Source: ${escapeHtml(source)}`);
  return [
    `<figure class="pdf-figure" style="${width}">`,
    // No loading="lazy": the data URI is already embedded, and lazy-loading would
    // defer the image past Puppeteer's initial viewport, leaving it blank in print.
    `<img src="${dataUri}" alt="${escapeAttr(attrs.alt || caption || 'Chart snapshot')}">`,
    capParts.length ? `<figcaption>${capParts.join(' | ')}</figcaption>` : '',
    '</figure>',
  ].join('');
}

// Resolve a plotly.html `src` (site-root-relative `/media/plots/…` or an
// absolute URL) to a Puppeteer navigation target and a local existence check.
function resolvePlotlyTarget(src) {
  if (/^https?:\/\//i.test(src)) {
    return { url: src, localPath: null };
  }
  const localPath = path.join(REPO_ROOT, 'content', src.replace(/^\/+/, ''));
  return { url: `file://${localPath}`, localPath };
}

async function screenshotPlotlyChart(browser, attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return null;

  const { url, localPath } = resolvePlotlyTarget(src);
  if (localPath && !fs.existsSync(localPath)) {
    console.warn(`Plotly chart not found, falling back to note: ${src}`);
    return null;
  }

  const heightRaw = parseInt(attrs.height, 10);
  const height = Number.isFinite(heightRaw) && heightRaw > 0 ? heightRaw : 480;

  const page = await browser.newPage();
  try {
    await page.setViewport({ width: 1000, height: height + 40, deviceScaleFactor: 2 });
    await page.goto(url, { waitUntil: 'networkidle0', timeout: 30000 });
    await page
      .waitForSelector('.js-plotly-plot .main-svg, .js-plotly-plot .gl-container', { timeout: 15000 })
      .catch(() => {});
    await new Promise((resolve) => setTimeout(resolve, 300));

    // The mode bar (zoom/pan/download icons) is inert in a static snapshot; hide it.
    await page.evaluate(() => {
      document.querySelectorAll('.modebar-container').forEach((el) => {
        el.style.display = 'none';
      });
    });

    const handle = (await page.$('.plotly-graph-div')) || (await page.$('body'));
    if (!handle) return null;
    const buffer = await handle.screenshot({ type: 'png' });
    return `data:image/png;base64,${buffer.toString('base64')}`;
  } catch (err) {
    console.warn(`Failed to screenshot Plotly chart (${src}): ${err.message}`);
    return null;
  } finally {
    await page.close();
  }
}

async function resolvePlotlyPlaceholders(bodyHtml, registry, browser) {
  let html = bodyHtml;
  for (const entry of registry) {
    const dataUri = await screenshotPlotlyChart(browser, entry.attrs);
    const replacement = dataUri ? plotlySnapshotHtml(entry.attrs, dataUri) : plotlyFallbackHtml(entry.attrs);
    html = html.replace(plotlyPlaceholder(entry.index), replacement);
  }
  return html;
}

function ongoingProductHtml() {
  return '<span class="pdf-badge">Currently active</span>';
}

// Mirrors normalizeDataPath in _includes/content-runtime/10-utils.html, but
// resolves against the on-disk YAML source instead of the exported JSON.
function resolveDataYamlPath(rawValue, fallbackDir) {
  let value = String(rawValue || '').trim();
  if (!value) return null;
  value = value.replace(/^content\/collections\/data\//, '');
  value = value.replace(/^_data\//, '');
  value = value.replace(/^data\//, '');
  if (!/\.(ya?ml)$/i.test(value)) {
    if (value.indexOf('/') === -1 && fallbackDir) value = `${fallbackDir}/${value}`;
    value = `${value}.yml`;
  }
  return path.join(REPO_ROOT, 'content/collections/data', value);
}

function loadDataYaml(rawValue, fallbackDir) {
  const filePath = resolveDataYamlPath(rawValue, fallbackDir);
  if (!filePath || !fs.existsSync(filePath)) return null;
  try {
    return yaml.load(fs.readFileSync(filePath, 'utf8'));
  } catch (err) {
    console.warn(`Failed to parse YAML data file (${filePath}): ${err.message}`);
    return null;
  }
}

function chordTabPlaceholder(index) {
  return `<div class="pdf-chordtab-placeholder" data-chordtab-id="${index}"></div>`;
}

function chordTabPdfHtml(data) {
  const sections = (data && Array.isArray(data.sections) && data.sections) || [];
  const introHtml = data && data.intro ? `<div class="pdf-chord-tab-intro"><pre>${escapeHtml(data.intro)}</pre></div>` : '';
  const sectionsHtml = sections
    .map((section) => {
      const label =
        section && section.label ? `<span class="pdf-chord-tab-section-label">${escapeHtml(section.label)}</span>` : '';
      const content = section && section.content ? escapeHtml(section.content) : '';
      return `<div class="pdf-chord-tab-section">${label}<pre>${content}</pre></div>`;
    })
    .join('');
  return ['<div class="pdf-chord-tab">', '<h2>Cifra</h2>', introHtml, sectionsHtml, '</div>'].join(
    '',
  );
}

function chordTabFallbackHtml() {
  return mediaNoteHtml('Chord tab omitted in PDF', '');
}

function resolveChordTabPlaceholders(bodyHtml, registry) {
  let html = bodyHtml;
  for (const entry of registry) {
    const rawPath = entry.attrs.path || entry.attrs.file || entry.attrs.src || entry.attrs.tab;
    const data = loadDataYaml(rawPath, 'tabs');
    const replacement = data ? chordTabPdfHtml(data) : chordTabFallbackHtml();
    html = html.replace(chordTabPlaceholder(entry.index), replacement);
  }
  return html;
}

function loadSiteConfig() {
  const configPath = path.join(REPO_ROOT, '_config.yml');
  try {
    const raw = fs.readFileSync(configPath, 'utf8');
    return yaml.load(raw) || {};
  } catch {
    return {};
  }
}

function collectXciteIndex() {
  const index = new Map();
  const roots = [
    path.join(REPO_ROOT, 'content/collections/articles'),
    path.join(REPO_ROOT, 'content/collections/posts'),
    path.join(REPO_ROOT, 'content/collections/products'),
    path.join(REPO_ROOT, 'content/collections/projects'),
  ];
  for (const dir of roots) {
    if (!fs.existsSync(dir)) continue;
    for (const name of fs.readdirSync(dir)) {
      if (!/\.(md|markdown)$/i.test(name)) continue;
      const full = path.join(dir, name);
      try {
        const text = fs.readFileSync(full, 'utf8');
        const parsed = splitFrontMatter(text);
        const key = String(parsed.data.key || '').trim();
        if (!key) continue;
        index.set(key, {
          title: parsed.data.title || key,
          type: path.basename(dir),
        });
      } catch {
        /* ignore unreadable files */
      }
    }
  }
  return index;
}

function xciteHtml(key, index, siteUrl) {
  const item = index.get(key);
  if (!item) return '<span class="pdf-xcite-missing">[' + escapeHtml(key) + '?]</span>';
  // Construct the URL based on the collection type, defaulting to articles if unknown
  const baseUrl = String(siteUrl || '').replace(/\/$/, '');
  let collectionSegment = 'articles';
  if (item.type === 'posts') collectionSegment = 'posts';
  else if (item.type === 'products') collectionSegment = 'products';
  else if (item.type === 'projects') collectionSegment = 'projects';

  const href = baseUrl + '/' + collectionSegment + '/' + escapeAttr(key) + '/';
  return '<a href="' + href + '" class="pdf-xcite" target="_blank" rel="noopener noreferrer"><em>' + escapeHtml(item.title) + '</em></a>';
}

function splitFrontMatter(text) {
  const cleaned = String(text || '').replace(/^\uFEFF/, '');
  if (!cleaned.startsWith('---\n') && !cleaned.startsWith('---\r\n')) {
    return { data: {}, body: cleaned };
  }
  const match = cleaned.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { data: {}, body: cleaned };
  let data = {};
  try {
    data = yaml.load(match[1]) || {};
  } catch (err) {
    throw new Error(`Failed to parse YAML front matter: ${err.message}`);
  }
  return { data, body: match[2] };
}


// --- Bibliography (Citations) ---

function collectBibIndex() {
  const index = {};
  const dir = path.join(REPO_ROOT, 'content/collections/bibliography');
  if (!fs.existsSync(dir)) return index;
  for (const name of fs.readdirSync(dir)) {
    if (!/\.ya?ml$/i.test(name)) continue;
    try {
      const text = fs.readFileSync(path.join(dir, name), 'utf8');
      const entry = yaml.load(text) || {};
      const key = path.basename(name, path.extname(name));
      index[key] = entry;
    } catch (err) {
      console.warn(`Failed to parse bib file ${name}: ${err.message}`);
    }
  }
  return index;
}

function bibField(entry, name) {
  return String(entry[name] == null ? '' : entry[name]).trim();
}

function splitBibAuthors(raw) {
  const authors = [];
  let current = '';
  let depth = 0;
  const text = String(raw || '');
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '{') {
      depth++;
      current += ch;
      continue;
    }
    if (ch === '}') {
      depth--;
      current += ch;
      continue;
    }
    if (depth === 0 && text.slice(i, i + 5) === ' and ') {
      if (current.trim()) authors.push(current.trim());
      current = '';
      i += 4;
      continue;
    }
    current += ch;
  }
  if (current.trim()) authors.push(current.trim());
  return authors;
}

function formatIeeeAuthor(name) {
  const author = String(name || '').trim();
  if (!author) return '';
  if (author.charAt(0) === '{' && author.charAt(author.length - 1) === '}') {
    return escapeHtml(author.slice(1, -1));
  }
  const parts = author.split(',');
  if (parts.length < 2) return escapeHtml(author);
  const last = parts[0].trim();
  const first = parts.slice(1).join(',').trim();
  const initials = first.split(/\s+/).filter(Boolean).map((word) => {
    return escapeHtml(word.charAt(0)) + '.';
  }).join(' ');
  return initials + ' ' + escapeHtml(last);
}

function formatIeeeAuthors(field) {
  const authors = splitBibAuthors(field);
  if (!authors.length) return '';
  const formatted = authors.map(formatIeeeAuthor);
  if (formatted.length === 1) return formatted[0];
  if (formatted.length === 2) return formatted[0] + ' and ' + formatted[1];
  return formatted.slice(0, -1).join(', ') + ', and ' + formatted[formatted.length - 1];
}

function formatIeeeEntry(entry, number) {
  const type = (entry && entry.type) || 'misc';
  const author = formatIeeeAuthors(bibField(entry, 'author'));
  const title = bibField(entry, 'title');
  const year = bibField(entry, 'year');
  const url = bibField(entry, 'url');
  const parts = [];

  if (type === 'book') {
    if (author) parts.push(author);
    if (title) parts.push('<em>' + escapeHtml(title) + '</em>');
    const publisher = bibField(entry, 'publisher');
    const tail = [publisher, year].filter(Boolean).join(', ');
    if (tail) parts.push(escapeHtml(tail) + '.');
  } else if (type === 'article') {
    if (author) parts.push(author + ',');
    if (title) parts.push('"' + escapeHtml(title) + ',"');
    const journal = bibField(entry, 'journal');
    if (journal) parts.push('<em>' + escapeHtml(journal) + '</em>');
    const meta = [];
    const volume = bibField(entry, 'volume');
    const issue = bibField(entry, 'number');
    const pages = bibField(entry, 'pages').replace(/--/g, '\u2013');
    if (volume) meta.push('vol. ' + escapeHtml(volume));
    if (issue) meta.push('no. ' + escapeHtml(issue));
    if (pages) meta.push('pp. ' + escapeHtml(pages));
    if (meta.length) parts.push(meta.join(', ') + ',');
    if (year) parts.push(escapeHtml(year) + '.');
  } else if (type === 'techreport') {
    if (author) parts.push(author + ',');
    if (title) parts.push('"' + escapeHtml(title) + ',"');
    const institution = bibField(entry, 'institution');
    if (institution) parts.push(escapeHtml(institution) + ',');
    if (year) parts.push(escapeHtml(year) + '.');
  } else {
    if (author) parts.push(author + ',');
    if (title) parts.push('"' + escapeHtml(title) + ',"');
    const howpublished = bibField(entry, 'howpublished');
    if (howpublished) parts.push(escapeHtml(howpublished) + ',');
    if (year) parts.push(escapeHtml(year) + '.');
  }

  const note = bibField(entry, 'note');
  if (note) parts.push(escapeHtml(note) + '.');

  let text = parts.join(' ');
  if (url) {
    text += ' [Online]. Available: <a href="' + escapeAttr(url) + '" target="_blank" rel="noopener noreferrer">' + escapeHtml(url) + '</a>';
  }
  return text;
}

function processCitations(markdown, bibIndex, citedKeysOut) {
  const keyToNumber = {};
  return String(markdown || '').replace(/\{%-?\s*cite\s+([^%\s]+)[\s\S]*?-?%\}/g, (_, rawKey) => {
    const key = String(rawKey || '').trim();
    if (!key) return '';
    if (!Object.prototype.hasOwnProperty.call(keyToNumber, key)) {
      citedKeysOut.push(key);
      keyToNumber[key] = citedKeysOut.length;
    }
    const number = keyToNumber[key];
    if (!bibIndex[key]) {
      return `<sup class='pdf-cite-missing'>[${escapeHtml(key)}?]</sup>`;
    }
    return `<sup class='pdf-cite'><a href='#cite-${escapeAttr(key)}'>[${number}]</a></sup>`;
  });
}

function buildReferencesHtml(citedKeys, bibIndex, lang) {
  if (!citedKeys.length) return '';
  const items = citedKeys.map((key, index) => {
    const number = index + 1;
    const entry = bibIndex[key];
    const body = entry ? formatIeeeEntry(entry, number) : `${escapeHtml(key)} (missing bibliography entry)`;
    return `<li id="cite-${escapeAttr(key)}"><span>[${number}]</span> ${body}</li>`;
  }).join('');
  const heading = String(lang || '').toLowerCase().startsWith('pt') ? 'Referências' : 'References';
  return `<div class="pdf-references">
<h2>${escapeHtml(heading)}</h2>
<ul class="pdf-bib-list">${items}</ul>
</div>`;
}

// --- End Bibliography ---

function formatDefHtml(def) {
  return escapeHtml(String(def || '').trim()).replace(/\r\n|\r|\n/g, '<br>');
}

function dictCardHtml(attrs) {
  const lemma = String(attrs.lemma || '').trim();
  if (!lemma) return '';
  const locale = String(attrs.locale || '').trim().toLowerCase();
  const meta = String(attrs.meta || '').trim();
  const label = String(attrs.country || meta || locale).trim();
  const note = String(attrs.note || '').trim();
  const source = String(attrs.source || '').trim();
  const url = String(attrs.url || '').trim();
  const accessed = String(attrs.accessed || '').trim();
  const citeExtra = String(attrs.cite_extra || '').trim();
  const linkLabel = String(attrs.link_label || url).trim();
  const parts = [
    `<article class="sov-card${locale ? ` sov-card--${escapeAttr(locale)}` : ''}" role="listitem">`,
    '<div class="sov-card__head">',
  ];
  if (locale) {
    parts.push(
      `<span class="sov-card__flag" title="${escapeAttr(label)}"><span class="fi fi-${escapeAttr(locale)}" role="img" aria-label="${escapeAttr(label)}"></span></span>`,
    );
  }
  if (meta) parts.push(`<span class="sov-card__meta">${escapeHtml(meta)}</span>`);
  parts.push('</div>');
  parts.push(`<p class="sov-card__lemma">${escapeHtml(lemma)}</p>`);
  if (attrs.def) parts.push(`<div class="sov-card__def">${formatDefHtml(attrs.def)}</div>`);
  if (note) parts.push(`<p class="sov-card__note">${note}</p>`);
  if (source) {
    let cite = `${escapeHtml(source)}, s.v. &ldquo;${escapeHtml(lemma)},&rdquo;`;
    if (url) cite += ` <a href="${escapeAttr(url)}">${escapeHtml(linkLabel)}</a>`;
    if (accessed) cite += `, accessed ${escapeHtml(accessed)}`;
    cite += '.';
    if (citeExtra) cite += ` ${escapeHtml(citeExtra)}`;
    parts.push(`<p class="sov-card__cite">${cite}</p>`);
  }
  parts.push('</article>');
  return parts.join('');
}

function tweetHtml(attrs) {
  const body = String(attrs.body || '').trim();
  if (!body) return '';
  const handle = String(attrs.handle || '').trim().replace(/^@/, '');
  const icon = String(attrs.icon || 'chat').trim() || 'chat';
  const url = String(attrs.url || '').trim();
  const date = String(attrs.date || '').trim();
  const note = String(attrs.note || '').trim();
  const name = String(attrs.name || '').trim();
  const linkLabel = url.replace(/^https?:\/\//, '');
  const parts = [
    '<article class="sov-tweet">',
    '<div class="sov-tweet__head">',
    `<span class="sov-tweet__avatar" aria-hidden="true"><span class="material-symbols-outlined">${escapeHtml(icon)}</span></span>`,
    '<span class="sov-tweet__id">',
  ];
  if (name) parts.push(`<span class="sov-tweet__name">${escapeHtml(name)}</span>`);
  if (handle) parts.push(`<span class="sov-tweet__handle">@${escapeHtml(handle)}</span>`);
  parts.push('</span></div>');
  parts.push(`<p class="sov-tweet__body">${body}</p>`);
  if (url || date) {
    let cite = '';
    if (url) cite += `<a href="${escapeAttr(url)}">${escapeHtml(linkLabel)}</a>`;
    if (url && date) cite += ' · ';
    if (date) cite += escapeHtml(date);
    parts.push(`<p class="sov-tweet__cite">${cite}</p>`);
  }
  if (note) parts.push(`<p class="sov-tweet__note">${note}</p>`);
  parts.push('</article>');
  return parts.join('');
}

function wrapDictCardGrid(html) {
  return String(html || '').replace(
    /(?:<article\b[^>]*\bsov-card\b[\s\S]*?<\/article>\s*){2,}/g,
    (block) => {
      if (/\bsov-grid\b/.test(block)) return block;
      return `<div class="sov-grid" role="list">${block.trim()}</div>\n`;
    },
  );
}

function preprocessLiquid(markdown, xciteIndex, plotlyRegistry, youtubeRegistry, chordTabRegistry, siteUrl) {
  const text = String(markdown || '')
    .replace(/\{%-?\s*include\s+cut-in\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => cutInHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+figure\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => figureHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+plotly\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => {
      const attrs = parseIncludeAttrs(raw);
      const index = plotlyRegistry.length;
      plotlyRegistry.push({ index, attrs });
      return plotlyPlaceholder(index);
    })
    .replace(/\{%-?\s*include\s+chord-tab\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => {
      const attrs = parseIncludeAttrs(raw);
      const index = chordTabRegistry.length;
      chordTabRegistry.push({ index, attrs });
      return chordTabPlaceholder(index);
    })
    .replace(/\{%-?\s*include\s+youtube-short\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => {
      const attrs = parseIncludeAttrs(raw);
      const ids = [attrs.src || attrs.id || attrs.id1, attrs.src2 || attrs.id2].filter(Boolean);
      return ids.map((id) => registerYoutubeCard(youtubeRegistry, { id, caption: attrs.caption, isShort: true })).join('');
    })
    .replace(/\{%-?\s*include\s+youtube\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => {
      const attrs = parseIncludeAttrs(raw);
      const id = attrs.id || attrs.youtube_id;
      return registerYoutubeCard(youtubeRegistry, { id, caption: attrs.caption, isShort: false });
    })
    .replace(/\{%-?\s*include\s+video\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => videoHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+dict-card\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => dictCardHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+tweet\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => tweetHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+ongoing-product\.html\s*-?%\}/g, () => ongoingProductHtml())
    .replace(/\{%-?\s*include\s+xcite\.html\s+key=["']([^"']+)["'][\s\S]*?-?%\}/g, (_, key) =>
      xciteHtml(key, xciteIndex, siteUrl),
    )
    .replace(/\{%-?\s*include\s+[\w.-]+\s+[\s\S]*?-?%\}/g, '')
    .replace(/\{%-?\s*assign\s+[\s\S]*?-?%\}/g, '');
  return wrapDictCardGrid(text);
}

function preprocessMarkdownDivs(markdown) {
  let text = String(markdown || '');
  text = text.replace(
    /<div\s+([^>]*class="[^"]*\barticle-note\b[^"]*"[^>]*)>([\s\S]*?)<\/div>/gi,
    (match, openTag, inner) => {
      if (!/\bmarkdown\s*=\s*["']1["']/i.test(openTag)) return match;
      return `<div class="article-note">${marked.parse(inner.trim())}</div>`;
    },
  );
  text = text.replace(
    /<div\s+([^>]*class="[^"]*\bpoem\b[^"]*"[^>]*)>([\s\S]*?)<\/div>/gi,
    (match, openTag, inner) => {
      if (!/\bmarkdown\s*=\s*["']1["']/i.test(openTag)) return match;
      return `<div class="poem"><p>${inner.trim()}</p></div>`;
    },
  );
  return text;
}

function formatDateTime(date, timeZone = 'Europe/Paris') {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date);
}

function htmlLang(languageRaw) {
  const raw = String(languageRaw || '').trim().toLowerCase();
  if (raw.startsWith('pt')) return 'pt';
  if (raw.startsWith('es')) return 'es';
  if (raw.startsWith('fr')) return 'fr';
  return 'en';
}

function buildHtml({ data, bodyHtml, site, generatedAt, hasMath }) {
  const identityName = site?.pandorga?.identity?.name || site.author || '';
  const author = data.author || identityName;
  const title = data.title || 'Untitled';
  const description = data.description || '';
  const year = String(generatedAt.getFullYear());
  const generatedLabel = formatDateTime(generatedAt, site.timezone || 'Europe/Paris');
  const authorUrl = String(site?.pandorga?.identity?.url || site.url || '').replace(/\/$/, '');

  // Same delimiters/config as _includes/mathjax.html; SVG output prints crisply at any scale.
  const mathJaxHtml = hasMath
    ? `<script>
  window.MathJax = {
    tex: {
      inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
      displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']]
    },
    svg: { fontCache: 'global' },
    startup: {
      typeset: true,
      pageReady: function () {
        return MathJax.startup.defaultPageReady().then(function () {
          window.__mathjaxReady = true;
        });
      }
    }
  };
  </script>
  <script src="https://cdn.jsdelivr.net/npm/mathjax@3.2.2/es5/tex-svg.js" id="MathJax-script"></script>`
    : '';

  return `<!DOCTYPE html>
<html lang="${escapeAttr(htmlLang(data.language))}">
<head>
  <meta charset="utf-8">
  <title>${escapeHtml(title)}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=STIX+Two+Text:ital,wght@0,400;0,600;1,400&family=Work+Sans:ital,wght@0,400;0,500;0,600;1,400&display=swap" rel="stylesheet">
  ${mathJaxHtml}
  <style>
    :root {
      --ink: #1a1c1c;
      --muted: #5c5f5f;
      --soft: #9a9c9c;
      --rule: #d8d9da;
      --panel: #f3f3f4;
      --primary: #34596b;
      --secondary: #3f6b4f;
      --tertiary: #5e5d42;
      --paper: #ffffff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      color: var(--ink);
      background: var(--paper);
      font-family: "Work Sans", "Helvetica Neue", sans-serif;
      font-size: 11pt;
      line-height: 1.65;
      /* One body line box; heading lead-in spacing is measured in these units. */
      --body-line: 18.15pt;
    }
    .sheet {
      max-width: 40rem;
      margin: 0 auto;
    }
    .masthead {
      border-bottom: 1px solid var(--rule);
      padding-bottom: 1rem;
      margin-bottom: 1.1rem;
    }
    h1.doc-title {
      font-family: "STIX Two Text", "Times New Roman", serif;
      /* 25% larger than the previous 1.85rem + 4pt title size (32.75pt at 16px root). */
      font-size: 32.75pt;
      font-weight: 600;
      line-height: 1.2;
      margin: 0 0 0.65rem;
      color: var(--ink);
    }
    .deck {
      font-size: 1.02rem;
      color: var(--muted);
      margin: 0 0 0.95rem;
      line-height: 1.45;
    }
    .byline {
      margin: 0 0 0.65rem;
      font-size: 0.84rem;
      color: var(--muted);
      line-height: 1.45;
    }
    .byline a {
      color: var(--muted);
      text-decoration: none;
      border-bottom: 1px solid var(--rule);
    }
    .byline a:hover { color: var(--primary); }
    .share-note {
      margin: 0;
      font-size: 0.78rem;
      color: var(--soft);
      line-height: 1.4;
    }
    /* Section titles: body face + semibold; #### matches body size, +3pt per level up.
       No rule or accent colour — hierarchy is size and spacing only.
       Lead-in shrinks with level importance (≈1.05 body line boxes at h4). */
    .body h1, .body h2, .body h3, .body h4 {
      font-family: "Work Sans", "Helvetica Neue", sans-serif;
      font-weight: 600;
      color: var(--ink);
      line-height: 1.3;
      page-break-after: avoid;
      break-after: avoid;
    }
    .body h1 {
      font-size: 20pt;
      margin: calc(1.68 * var(--body-line)) 0 calc(0.715 * var(--body-line));
    }
    .body h2 {
      font-size: 17pt;
      margin: calc(1.47 * var(--body-line)) 0 calc(0.65 * var(--body-line));
    }
    .body h3 {
      font-size: 14pt;
      margin: calc(1.26 * var(--body-line)) 0 calc(0.585 * var(--body-line));
    }
    .body h4 {
      font-size: 11pt;
      margin: calc(1.05 * var(--body-line)) 0 calc(0.52 * var(--body-line));
    }
    .body p { margin: 0 0 var(--body-line); }
    .body hr {
      border: 0;
      border-top: 1px solid var(--rule);
      margin: 1.2rem 0;
      clear: both;
    }
    .body img.article-cut-in {
      float: left;
      display: block;
      width: calc(6 * var(--body-line) * 3 / 4);
      height: calc(6 * var(--body-line));
      max-width: 36%;
      object-fit: cover;
      object-position: center 18%;
      margin: 0.15em 0.9em 0.45em 0;
    }
    .body img.article-cut-in--right {
      float: right;
      margin: 0.15em 0 0.45em 0.9em;
    }
    .body a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
    .body ul, .body ol { margin: 0 0 0.85rem 1.25rem; }
    .body li { margin-bottom: 0.25rem; }
    .body blockquote {
      margin: 0 0 1rem;
      padding: 0.15rem 0 0.15rem 0.9rem;
      border-left: 3px solid var(--tertiary);
      color: var(--muted);
    }
    .body table {
      width: 100%;
      border-collapse: collapse;
      margin: 0 0 1rem;
      font-size: 0.92rem;
    }
    .body th, .body td {
      border: 1px solid var(--rule);
      padding: 0.35rem 0.5rem;
      text-align: left;
      vertical-align: top;
    }
    .body th { background: var(--panel); font-weight: 600; }
    .body code {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.88em;
      background: var(--panel);
      padding: 0.05em 0.3em;
    }
    .body pre {
      background: var(--panel);
      padding: 0.75rem 0.9rem;
      overflow-x: auto;
      font-size: 0.82rem;
      margin: 0 0 1rem;
    }
    .body pre code { background: none; padding: 0; }
    .pdf-figure {
      margin: 1.1rem auto;
      text-align: center;
      page-break-inside: avoid;
    }
    .pdf-figure img {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 0 auto;
    }

    .pdf-figure figcaption {
      margin-top: 0.4rem;
      font-size: 0.78rem;
      color: var(--muted);
      font-style: italic;
    }
    /* Bibliography */
    sup.pdf-cite, sup.pdf-cite-missing { font-size: 0.75em; line-height: 0; vertical-align: super; }
    sup.pdf-cite a { color: var(--primary); text-decoration: none; }
    sup.pdf-cite-missing { color: var(--muted); }
    .pdf-references { margin-top: 2rem; border-top: 1px solid var(--rule); padding-top: 1rem; }
    .pdf-references h2 { font-size: 1.2rem; font-weight: 600; margin-bottom: 1rem; color: var(--ink); border: none; padding: 0; }
    .pdf-bib-list { list-style: none; padding-left: 0; margin-left: 0; }
    .pdf-bib-list li { margin-bottom: 0.8rem; font-size: 0.92rem; line-height: 1.5; text-indent: -1.8rem; padding-left: 1.8rem; }
    .pdf-bib-list li span:first-child { display: inline-block; width: 1.8rem; text-indent: 0; color: var(--muted); }
    .pdf-bib-list li a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }

    /* Dictionary & Tweets */
    .sov-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.0rem;
      margin: 1.25rem 0 1.75rem;
      page-break-inside: avoid;
    }
    .sov-card {
      border: 1px solid color-mix(in srgb, var(--rule) 45%, transparent);
      border-left: 3px solid var(--secondary);
      border-radius: 0;
      background: color-mix(in srgb, var(--panel) 92%, transparent);
      padding: 0.7rem 0.85rem 0.8rem;
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
      min-width: 0;
      font-size: 0.85rem;
    }
    .sov-card p { margin: 0; }
    .sov-card__head {
      display: flex;
      align-items: center;
      gap: 0.55rem;
      flex-wrap: wrap;
    }
    .sov-card__flag {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      height: 1.65rem;
      padding: 0 0.4rem;
      border: 1.5px solid color-mix(in srgb, currentColor 40%, var(--rule));
      border-radius: 0;
      line-height: 1;
    }
    .sov-card__meta {
      font-size: 0.72rem;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      opacity: 0.8;
      font-weight: 600;
    }
    .sov-card__lemma { font-weight: 600; font-size: 1.05rem; }
    .sov-card__def { font-size: 0.95em; }
    .sov-card__cite, .sov-card__note { font-size: 0.82em; opacity: 0.8; }
    .sov-tweet {
      max-width: 34rem;
      margin: 1.25rem 0 1.75rem;
      padding: 0.95rem 1.15rem 1rem;
      border: 1px solid color-mix(in srgb, var(--rule) 45%, transparent);
      border-radius: 0;
      background: color-mix(in srgb, var(--panel) 92%, transparent);
      font-size: 0.95rem;
      page-break-inside: avoid;
    }
    .sov-tweet p { margin: 0; }
    .sov-tweet__head {
      display: flex;
      align-items: center;
      gap: 0.55rem;
      margin-bottom: 0.85rem;
    }
    .sov-tweet__avatar {
      width: 2.2rem;
      height: 2.2rem;
      background: color-mix(in srgb, var(--primary) 25%, transparent);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-weight: 300;
      font-size: 1.25rem;
    }
    .sov-tweet__id {
      display: flex;
      flex-direction: column;
      line-height: 1.15;
    }
    .sov-tweet__name { font-weight: 700; font-size: 0.95rem; }
    .sov-tweet__handle { font-size: 0.82rem; opacity: 0.75; }
    .sov-tweet__body {
      margin: 0 0 0.5rem !important;
      font-size: 0.98rem;
      line-height: 1.65;
    }
    .sov-tweet__body em { font-style: italic; }
    .sov-tweet__cite {
      margin: 0 0 0.55rem !important;
      font-size: 0.82rem;
      line-height: 1.5;
      opacity: 0.8;
    }
    .sov-tweet__cite a { text-decoration: none; }
    .sov-tweet__note {
      margin: 0 !important;
      font-size: 0.88rem;
      line-height: 1.6;
      opacity: 0.9;
    }

    /* End-of-section brand strips (raw HTML in Markdown).
       One body line box before and after (same unit as heading lead-in). */
    .article-brand-strip {
      display: block;
      text-align: center;
      margin: var(--body-line) 0;
      line-height: 0;
      page-break-inside: avoid;
      break-inside: avoid;
    }
    .article-brand-strip img {
      display: inline-block;
      vertical-align: middle;
      width: auto;
      height: 2.4rem;
      max-width: 12rem;
      object-fit: contain;
    }
    .article-brand-strip img + img {
      margin-left: 2ch;
    }
    .article-brand-strip-dark {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      box-sizing: border-box;
      padding: 0.25rem 0.4rem;
      background: #111;
    }
    .article-brand-strip-dark img { height: 2rem; }
    .pdf-media-note {
      margin: 0.9rem 0;
      padding: 0.65rem 0.8rem;
      border: 1px solid var(--rule);
      background: var(--panel);
      font-size: 0.85rem;
      color: var(--muted);
    }
    .pdf-badge {
      display: inline-block;
      padding: 0.1rem 0.45rem;
      background: var(--panel);
      font-size: 0.78rem;
      color: var(--muted);
    }
    .pdf-xcite { color: var(--secondary); font-style: italic; }
    .pdf-xcite-missing { color: var(--muted); }
    mjx-container { overflow-x: auto; max-width: 100%; }
    mjx-container[display="true"] { margin: 0.6rem 0 1rem; }
    /* Readable substitute for embeds that cannot play in a static PDF: a linked
       thumbnail (or plain icon) plus a "go watch it" link — no "omitted" wording. */
    .pdf-media-card {
      margin: 1.1rem 0;
      border: 1px solid var(--rule);
      page-break-inside: avoid;
    }
    .pdf-media-thumb-link {
      display: block;
      position: relative;
      text-decoration: none;
      line-height: 0;
    }
    .pdf-media-thumb-link img {
      display: block;
      width: 100%;
      height: auto;
    }
    .pdf-media-play {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 2.4rem;
      height: 2.4rem;
      border-radius: 50%;
      background: rgba(20, 20, 20, 0.68);
      color: #fff;
      font-size: 0.95rem;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .pdf-media-noimg {
      padding: 1.1rem 0;
      text-align: center;
      background: var(--panel);
    }
    .pdf-media-noimg .pdf-media-play {
      position: static;
      transform: none;
      display: inline-flex;
      background: var(--muted);
    }
    .pdf-media-caption {
      padding: 0.6rem 0.8rem;
      font-size: 0.85rem;
      color: var(--muted);
    }
    .pdf-media-caption strong { display: block; color: var(--ink); margin-bottom: 0.15rem; }
    .pdf-media-desc { display: block; margin-bottom: 0.3rem; }
    .pdf-media-caption a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
    .pdf-chord-tab { margin: 1.6rem 0 0.4rem; }
    .pdf-chord-tab h2 {
      font-size: 1.25rem;
      font-weight: 400;
      margin: 1.4rem 0 0.7rem;
      padding-top: 0.9rem;
      border-top: 1px solid var(--rule);
      color: var(--ink);
    }
    .pdf-chord-tab pre {
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 0.7rem;
      line-height: 1.55;
      white-space: pre;
      margin: 0;
      color: var(--ink);
    }
    .pdf-chord-tab-intro { margin: 0 0 1rem; }
    .pdf-chord-tab-intro pre { color: var(--tertiary); }
    .pdf-chord-tab-section { margin-bottom: 1.1rem; page-break-inside: avoid; }
    .pdf-chord-tab-section-label {
      display: block;
      font-size: 0.72rem;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--tertiary);
      margin-bottom: 0.3rem;
    }
    .article-note {
      margin: 1rem 0;
      padding: 0.75rem 0.9rem;
      background: var(--panel);
      border-left: 3px solid var(--tertiary);
      font-size: 0.92rem;
    }
    .poem p {
      white-space: pre-line;
      margin: 0 0 0.75rem;
    }
    .end-mark {
      margin-top: 2rem;
      padding-top: 0.75rem;
      border-top: 1px solid var(--rule);
      font-size: 0.75rem;
      color: var(--muted);
    }
    @media print {
      a { color: var(--primary); }
    }
  </style>
</head>
<body>
  <main class="sheet">
    <header class="masthead">
      <h1 class="doc-title">${escapeHtml(title)}</h1>
      ${description ? `<p class="deck">${escapeHtml(description)}</p>` : ''}
      <p class="byline">Written by <a href="${escapeAttr(authorUrl)}">${escapeHtml(author)}</a> | Generated ${escapeHtml(generatedLabel)}</p>
      <p class="share-note">Private document. Redistribution or publication without permission is not allowed.</p>
    </header>
    <article class="body">
      ${bodyHtml}
    </article>
  </main>
</body>
</html>`;
}

async function launchBrowser() {
  return puppeteer.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
}

async function writePdf(browser, html, outputPath, footerMeta) {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });

  const page = await browser.newPage();
  try {
    await page.setContent(html, { waitUntil: 'networkidle0', timeout: 120000 });

    const hasMathJax = await page.evaluate(() => typeof window.MathJax !== 'undefined');
    if (hasMathJax) {
      await page
        .waitForFunction('window.__mathjaxReady === true', { timeout: 20000 })
        .catch((err) => console.warn(`MathJax did not finish typesetting before timeout: ${err.message}`));
    }

    const shortTitle =
      footerMeta.title.length > 48 ? `${footerMeta.title.slice(0, 45)}…` : footerMeta.title;

    await page.pdf({
      path: outputPath,
      format: 'A4',
      printBackground: true,
      displayHeaderFooter: true,
      headerTemplate: '<div></div>',
      // Footer size matches masthead .share-note (0.78rem ≈ 12.5px). Self-contained
      // HTML — does not load site CSS, so the site root rem scale never applies.
      footerTemplate: `
        <div style="width:100%;font-size:12.5px;color:#9a9c9c;font-family:Work Sans,Helvetica,sans-serif;padding:0 14mm;display:flex;justify-content:space-between;align-items:center;">
          <span>© ${escapeHtml(footerMeta.year)}</span>
          <span>${escapeHtml(shortTitle)}</span>
          <span><span class="pageNumber"></span>/<span class="totalPages"></span></span>
        </div>
      `,
      margin: { top: '16mm', right: '16mm', bottom: '18mm', left: '16mm' },
    });
  } finally {
    await page.close();
  }
}

async function main() {
  const { input, output } = parseArgs(process.argv.slice(2));
  const inputPath = path.resolve(input);
  const outputPath = path.resolve(output);

  if (!fs.existsSync(inputPath)) {
    console.error(`Input not found: ${inputPath}`);
    process.exit(1);
  }

  const site = loadSiteConfig();
  const source = fs.readFileSync(inputPath, 'utf8');
  const { data, body } = splitFrontMatter(source);
  const xciteIndex = collectXciteIndex();
  const plotlyRegistry = [];
  const youtubeRegistry = [];
  const chordTabRegistry = [];
  const hasMath = containsMathMarkup(body);
  const bodyHasChordInclude = /\{%-?\s*include\s+chord-tab\.html/.test(body);

  const bibIndex = collectBibIndex();
  const citedKeys = [];
  const mathRegistry = [];
  let prepared = preprocessMarkdownDivs(
    preprocessLiquid(processCitations(body, bibIndex, citedKeys), xciteIndex, plotlyRegistry, youtubeRegistry, chordTabRegistry, String(site?.pandorga?.identity?.url || site.url || '')),
  );
  if (hasMath) prepared = extractMathRegions(prepared, mathRegistry);
  // Mirrors the content runtime: front-matter `tab:` renders at the end of the
  // body when the writer did not place an explicit chord-tab include.
  if (data.tab && !bodyHasChordInclude) {
    const index = chordTabRegistry.length;
    chordTabRegistry.push({ index, attrs: { tab: data.tab } });
    prepared += `\n\n${chordTabPlaceholder(index)}\n`;
  }

  let bodyHtml = marked.parse(prepared, { gfm: true, breaks: false });
  if (hasMath) bodyHtml = restoreMathRegions(bodyHtml, mathRegistry);
  bodyHtml = await resolveYoutubePlaceholders(bodyHtml, youtubeRegistry);
  bodyHtml = resolveChordTabPlaceholders(bodyHtml, chordTabRegistry);
  if (citedKeys.length) {
    bodyHtml += '\n' + buildReferencesHtml(citedKeys, bibIndex, data.language);
  }
  const generatedAt = new Date();
  const title = data.title || path.basename(inputPath, path.extname(inputPath));

  const browser = await launchBrowser();
  try {
    bodyHtml = await resolvePlotlyPlaceholders(bodyHtml, plotlyRegistry, browser);
    const html = buildHtml({ data, bodyHtml, site, generatedAt, hasMath });
    await writePdf(browser, html, outputPath, {
      title,
      year: String(generatedAt.getFullYear()),
    });
  } finally {
    await browser.close();
  }

  const sizeKb = Math.round(fs.statSync(outputPath).size / 1024);
  console.log(`PDF written: ${outputPath} (${sizeKb} KB)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
