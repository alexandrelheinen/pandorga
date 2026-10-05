// load-runtime.mjs — assemble and evaluate the real content runtime in Node.
//
// Listings and detail views render in the browser from JS string templates
// spread over _includes/content-runtime/*.html. A Ruby gate cannot see them
// and a Jekyll build never executes them, which is how a block that renders
// an element with no backing field ships green. This loader concatenates the
// partials in the exact order _includes/page/content-runtime.html includes
// them, evaluates the result beNewsreader a deliberately thin DOM shim, and hands
// back the same object 90-bootstrap.html returns to the browser.
//
// The shim is small on purpose: createElement, className, setAttribute,
// innerHTML, and just enough child-node traversal for textExcerpt(). No DOM
// library is vendored, and pulling one in would hide which browser APIs the
// runtime actually depends on. Anything a block starts using that is missing
// here fails loudly rather than quietly returning undefined.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// marked lives in scripts/node_modules; the render-parity gate already runs
// node from scripts/. Without it renderMarkdown falls back to a single
// escaped paragraph, which is enough for the blocks but makes excerpt
// assertions meaningless, so import it when it resolves.
let marked;
try {
  ({ marked } = await import('marked'));
} catch {
  marked = undefined;
}

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(HERE, '..', '..', '..');
const ASSEMBLY = path.join(REPO_ROOT, '_includes', 'page', 'content-runtime.html');
const PARTIAL_DIR = path.join(REPO_ROOT, '_includes', 'content-runtime');

const VOID_TAGS = new Set(['img', 'br', 'hr', 'input', 'meta', 'link', 'source']);

const NODE = { ELEMENT_NODE: 1, TEXT_NODE: 3, COMMENT_NODE: 8 };

const ENTITIES = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#39;': "'",
  '&#96;': '`',
  '&nbsp;': ' '
};

function decodeEntities(text) {
  return String(text).replace(/&(?:amp|lt|gt|quot|nbsp|#39|#96);/g, (m) => ENTITIES[m] ?? m);
}

function makeTextNode(text) {
  return { nodeType: NODE.TEXT_NODE, textContent: decodeEntities(text), childNodes: [] };
}

// A deliberately small HTML parser. textExcerpt() walks childNodes and reads
// textContent, so a shim that only stored innerHTML as a string would make
// every listing preview come back empty and the excerpt assertions vacuous.
function parseHtml(html) {
  const nodes = [];
  const stack = [{ childNodes: nodes }];
  const token = /<!--[\s\S]*?-->|<\/([a-zA-Z][\w-]*)\s*>|<([a-zA-Z][\w-]*)((?:"[^"]*"|'[^']*'|[^>"'])*?)(\/?)>/g;
  let cursor = 0;
  let match;

  const push = (node) => stack[stack.length - 1].childNodes.push(node);
  const text = (raw) => {
    if (raw) push(makeTextNode(raw));
  };

  while ((match = token.exec(html)) !== null) {
    text(html.slice(cursor, match.index));
    cursor = token.lastIndex;
    if (match[0].startsWith('<!--')) continue;

    if (match[1]) {
      const closing = match[1].toLowerCase();
      for (let i = stack.length - 1; i > 0; i -= 1) {
        if (stack[i].tagName && stack[i].tagName.toLowerCase() === closing) {
          stack.length = i;
          break;
        }
      }
      continue;
    }

    const element = makeElement(match[2]);
    const attrs = /([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g;
    let attr;
    while ((attr = attrs.exec(match[3] || '')) !== null) {
      element.setAttribute(attr[1], decodeEntities(attr[2] ?? attr[3] ?? ''));
    }
    push(element);
    if (!match[4] && !VOID_TAGS.has(element.tagName.toLowerCase())) stack.push(element);
  }
  text(html.slice(cursor));
  return nodes;
}

function collectText(node) {
  if (node.nodeType === NODE.TEXT_NODE) return node.textContent;
  return (node.childNodes || []).map(collectText).join('');
}

function serializeAttrs(element) {
  const pairs = [];
  if (element.className) pairs.push(['class', element.className]);
  for (const [key, value] of element._attrs) {
    if (key === 'class') continue;
    pairs.push([key, value]);
  }
  return pairs.map(([k, v]) => ` ${k}="${v}"`).join('');
}

function makeElement(tagName) {
  const tag = String(tagName).toLowerCase();
  const element = {
    nodeType: NODE.ELEMENT_NODE,
    tagName: tag.toUpperCase(),
    className: '',
    _innerHTML: '',
    childNodes: [],
    children: [],
    _attrs: new Map(),
    get innerHTML() {
      return this._innerHTML;
    },
    set innerHTML(value) {
      this._innerHTML = String(value ?? '');
      this._appended = [];
      this._sync();
    },
    _appended: [],
    _sync() {
      this.childNodes = parseHtml(this._innerHTML).concat(this._appended);
      this.children = this.childNodes.filter((n) => n.nodeType === NODE.ELEMENT_NODE);
    },
    get textContent() {
      return collectText(this);
    },
    set textContent(value) {
      this.innerHTML = String(value ?? '').replace(/[<>&]/g, (c) => `&#${c.charCodeAt(0)};`);
    },
    setAttribute(key, value) {
      if (key === 'class') this.className = String(value);
      else this._attrs.set(key, String(value));
    },
    getAttribute(key) {
      if (key === 'class') return this.className;
      return this._attrs.has(key) ? this._attrs.get(key) : null;
    },
    hasAttribute(key) {
      return key === 'class' ? this.className !== '' : this._attrs.has(key);
    },
    removeAttribute(key) {
      this._attrs.delete(key);
    },
    appendChild(child) {
      this._appended.push(child);
      this._sync();
      return child;
    },
    addEventListener() { },
    classList: {
      add: (name) => {
        const names = element.className.split(/\s+/).filter(Boolean);
        if (!names.includes(name)) names.push(name);
        element.className = names.join(' ');
      },
      remove: (name) => {
        element.className = element.className
          .split(/\s+/)
          .filter((n) => n && n !== name)
          .join(' ');
      },
      contains: (name) => element.className.split(/\s+/).includes(name)
    },
    querySelector() {
      return null;
    },
    querySelectorAll() {
      return [];
    },
    closest() {
      return null;
    },
    get outerHTML() {
      const attrs = serializeAttrs(this);
      if (VOID_TAGS.has(tag)) return `<${tag}${attrs}>`;
      const appended = this._appended.map((child) => child.outerHTML || '').join('');
      return `<${tag}${attrs}>${this._innerHTML}${appended}</${tag}>`;
    }
  };
  return element;
}

function makeSandbox(overrides = {}) {
  const documentShim = {
    readyState: 'loading',
    createElement: makeElement,
    createDocumentFragment: () => makeElement('div'),
    addEventListener() { },
    removeEventListener() { },
    dispatchEvent() { },
    querySelector() {
      return null;
    },
    querySelectorAll() {
      return [];
    },
    getElementById() {
      return null;
    },
    body: makeElement('body'),
    documentElement: makeElement('html')
  };

  const windowShim = {
    ContentRuntimeConfig: {
      contentBase: '',
      includeUnpublished: false,
      defaultAuthor: 'Test Author',
      translations: {},
      tocMinHeadings: 3
    },
    location: {
      origin: 'https://example.test',
      pathname: '/pages/articles/',
      search: '',
      href: 'https://example.test/pages/articles/'
    },
    document: documentShim,
    marked,
    matchMedia: () => ({ matches: false, addEventListener() { }, addListener() { } }),
    addEventListener() { },
    setTimeout,
    clearTimeout,
    requestAnimationFrame: (fn) => setTimeout(fn, 0),
    ...overrides
  };
  windowShim.window = windowShim;

  return { windowShim, documentShim };
}

function includeOrder() {
  const assembly = fs.readFileSync(ASSEMBLY, 'utf8');
  const names = [];
  const pattern = /\{%\s*include\s+content-runtime\/([\w.-]+\.html)\s*%\}/g;
  let match;
  while ((match = pattern.exec(assembly)) !== null) {
    // 00-config.html is a <script> tag outside the IIFE, not runtime source.
    if (match[1] === '00-config.html') continue;
    names.push(match[1]);
  }
  if (names.length === 0) {
    throw new Error(`No content-runtime includes found in ${ASSEMBLY}`);
  }
  return names;
}

// Every runtime partial is wrapped in {% raw %} so Liquid leaves the JS alone.
// The JS inside contains {% ... %} in regex literals, so the check has to be
// "no Liquid outside a raw region", not "no braces anywhere".
function stripRawMarkers(name, body) {
  const parts = body.split(/\{%-?\s*(?:end)?raw\s*-?%\}/);
  const outside = parts.filter((_, index) => index % 2 === 0).join('');
  if (/\{[{%]/.test(outside)) {
    throw new Error(`${name} contains Liquid outside {% raw %}; the loader cannot evaluate it`);
  }
  return parts.join('');
}

/** The assembled runtime source, in include order, with Liquid markers gone. */
export function runtimeSource() {
  return includeOrder()
    .map((name) => {
      const body = fs.readFileSync(path.join(PARTIAL_DIR, name), 'utf8');
      return `/* ---- ${name} ---- */\n${stripRawMarkers(name, body)}`;
    })
    .join('\n');
}

// 90-bootstrap.html ends the IIFE with `return { ... }`, so nothing can be
// appended after it. Some functions worth testing — hydrateFrontMatter above
// all — are deliberately not on that export list. Getters prepended to the
// body close over the whole scope and resolve on access, which works for
// hoisted function declarations and for `var` bindings alike, and costs the
// browser bundle nothing because it only exists here.
function exposeInternals(names) {
  if (!names.length) return '';
  const props = names.map((name) => `  get ${name}() { return ${name}; }`).join(',\n');
  return `window.__runtimeInternals = {\n${props}\n};\n`;
}

/**
 * Evaluate the runtime and return the object 90-bootstrap.html exports,
 * together with the shims so a caller can inspect what the runtime touched.
 *
 * @param {object} options
 * @param {string[]} [options.expose] runtime-internal names to reach as well
 */
export function loadRuntime(options = {}) {
  const { expose = [], ...overrides } = options;
  const { windowShim, documentShim } = makeSandbox(overrides);
  const factory = new Function(
    'window',
    'document',
    'Node',
    'DOMParser',
    `'use strict';\n${exposeInternals(expose)}${runtimeSource()}`
  );
  const runtime = factory(windowShim, documentShim, NODE, function DOMParser() {
    throw new Error('The runtime reached DOMParser; the loader has no XML parser');
  });
  if (!runtime || typeof runtime !== 'object') {
    throw new Error('The content runtime did not return its export object');
  }
  const internals = windowShim.__runtimeInternals || {};
  expose.forEach((name) => {
    if (internals[name] === undefined) {
      throw new Error(`The content runtime defines no "${name}" to expose`);
    }
  });
  return { runtime, internals, window: windowShim, document: documentShim };
}

/** Render a block that returns a DOM node or a string, uniformly as HTML. */
export function toHtml(result) {
  if (result == null) return '';
  if (typeof result === 'string') return result;
  if (typeof result.outerHTML === 'string') return result.outerHTML;
  throw new Error(`Cannot serialize block result of type ${typeof result}`);
}
