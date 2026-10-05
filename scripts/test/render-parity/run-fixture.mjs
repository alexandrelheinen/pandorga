#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { marked } from 'marked';
import { missingSelectors } from './selectors.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseIncludeAttrs(raw) {
  const attrs = {};
  let text = String(raw || '');
  text = text.replace(/([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g, (_, key, dbl, sgl) => {
    attrs[key] = dbl != null ? dbl : sgl;
    return '';
  });
  text.replace(/([\w-]+)\s*=\s*([^\s]+)/g, (_, key, val) => {
    if (!(key in attrs)) attrs[key] = val;
    return '';
  });
  return attrs;
}

function escapeAttr(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
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
  return `<figure class="article-cut-in-plate${sideClass}"><img class="article-cut-in${sideClass}" src="${escapeAttr(src)}" alt="${escapeAttr(attrs.alt || '')}" width="120" loading="lazy"></figure>`;
}

function figureHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return '';
  const width = attrs.width ? `max-width:${escapeAttr(attrs.width)}%;` : 'max-width:100%;';
  const caption = attrs.caption || '';
  const lbAttr = caption ? ` data-lightbox-caption="${escapeAttr(caption)}"` : '';
  return [
    `<figure class="my-8 mx-auto text-center w-full" style="display:block;${width}">`,
    `<img class="figure-lightbox-trigger" src="${escapeAttr(src)}" alt="${escapeAttr(attrs.alt || caption)}" loading="lazy" tabindex="0" role="button" aria-label="Enlarge image"${lbAttr}>`,
    caption ? `<figcaption class="mt-3">${escapeAttr(caption)}</figcaption>` : '',
    '</figure>'
  ].join('');
}

function plotlyHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return '';
  const width = attrs.width ? String(attrs.width).trim() : '100';
  const height = attrs.height && /^\d+$/.test(String(attrs.height).trim())
    ? String(attrs.height).trim()
    : '480';
  const caption = attrs.caption || '';
  const title = attrs.alt || caption || 'Interactive chart';
  return [
    `<figure class="plotly-figure my-8 mx-auto text-center w-full" style="display:block;max-width:${escapeAttr(width)}%;">`,
    `<iframe class="plotly-embed-frame" src="${escapeAttr(src)}" title="${escapeAttr(title)}" loading="lazy" scrolling="no" style="width:100%;height:${escapeAttr(height)}px;border:0;display:block;"></iframe>`,
    caption ? `<figcaption class="mt-3">${escapeAttr(caption)}</figcaption>` : '',
    '</figure>'
  ].join('');
}

function youtubeHtml(attrs, isShort) {
  const id = attrs.id || attrs.youtube_id || (isShort ? attrs.src : '');
  if (!id) return '';
  const aspect = isShort ? 'aspect-ratio: 9 / 16;' : 'aspect-ratio: 16 / 9;';
  return `<figure class="my-8 mx-auto text-center w-full"><div style="${aspect}"><iframe src="https://www.youtube.com/embed/${escapeAttr(id)}"></iframe></div></figure>`;
}

function youtubeShortHtml(attrs) {
  const src = attrs.src || attrs.id || attrs.id1;
  const src2 = attrs.src2 || attrs.id2;
  if (!src) return '';
  const frame = (id) =>
    `<iframe width="315" height="560" src="https://www.youtube.com/embed/${escapeAttr(id)}" title="YouTube short"></iframe>`;
  return `<figure class="my-8 mx-auto text-center w-full"><div class="article-youtube-short${src2 ? ' article-youtube-short--pair' : ''}">${frame(src)}${src2 ? frame(src2) : ''}</div></figure>`;
}

function videoHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return '';
  return `<figure><video controls src="${escapeAttr(src)}"></video>${attrs.caption ? `<figcaption>${escapeAttr(attrs.caption)}</figcaption>` : ''}</figure>`;
}

function ongoingProductHtml() {
  return '<span class="ongoing-product-badge" style="display: inline-block; padding: 0.15rem 0.5rem; background: var(--color-surface-container-low); border-radius: 0.25rem; font-size: 0.8rem; color: var(--color-on-surface-variant);">Currently active</span>';
}

function preprocessLiquid(markdown) {
  return String(markdown)
    .replace(/\{%-?\s*include\s+cut-in\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => cutInHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+figure\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => figureHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+plotly\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => plotlyHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+youtube-short\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => youtubeShortHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+youtube\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => youtubeHtml(parseIncludeAttrs(raw), false))
    .replace(/\{%-?\s*include\s+video\.html\s+([\s\S]*?)-?%\}/g, (_, raw) => videoHtml(parseIncludeAttrs(raw)))
    .replace(/\{%-?\s*include\s+ongoing-product\.html\s*-?%\}/g, () => ongoingProductHtml());
}

function hasMarkdownAttr(openTag) {
  return /\bmarkdown\s*=\s*["']1["']/i.test(String(openTag || ''));
}

function preprocessMarkdownDivs(markdown) {
  let text = String(markdown || '');
  text = text.replace(/<div\s+([^>]*class="[^"]*\barticle-note\b[^"]*"[^>]*)>([\s\S]*?)<\/div>/gi, (match, openTag, inner) => {
    if (!hasMarkdownAttr(openTag)) return match;
    return `<div class="article-note">${marked.parse(inner.trim())}</div>`;
  });
  text = text.replace(/<div\s+([^>]*class="[^"]*\bpoem\b[^"]*"[^>]*)>([\s\S]*?)<\/div>/gi, (match, openTag, inner) => {
    if (!hasMarkdownAttr(openTag)) return match;
    return `<div class="poem"><p>${inner.trim()}</p></div>`;
  });
  return text;
}

function render(markdown) {
  const prepared = preprocessMarkdownDivs(preprocessLiquid(markdown));
  return marked.parse(prepared, { gfm: true, breaks: false });
}

const fixturePath = process.argv[2];
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const html = render(fixture.markdown);
const missing = missingSelectors(html, fixture.selectors);

if (missing.length) {
  console.error(`Fixture ${fixture.name}: missing selectors ${missing.join(', ')}`);
  console.error(html);
  process.exit(1);
}

if (fixture.paragraphCount != null) {
  const count = (html.match(/<p\b/gi) || []).length;
  if (count !== fixture.paragraphCount) {
    console.error(`Fixture ${fixture.name}: expected ${fixture.paragraphCount} <p>, got ${count}`);
    console.error(html);
    process.exit(1);
  }
}

console.log(`Fixture ${fixture.name}: OK`);
