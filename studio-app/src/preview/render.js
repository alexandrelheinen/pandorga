/**
 * Studio side-preview: include → HTML (content-runtime–aligned where practical).
 * Spec: AC-STU-05. Cite/xcite pills start neutral; main.js resolves existence.
 */

import { marked } from "marked";

function escapeAttr(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function unwrapMediaSrc(path) {
  const value = String(path == null ? "" : path).trim();
  if (!value) return "";
  const md = value.match(/^\[([^\]]*)\]\(([^)\s]+)\)\s*$/);
  if (md) return String(md[2] || "").trim();
  return value;
}

/** Percent width from Liquid attrs; strips a trailing % so "80" and "80%" both work. */
function maxWidthCss(width, fallback = "100") {
  let w = String(width == null || width === "" ? fallback : width).trim();
  if (!w) w = fallback;
  w = w.replace(/%$/, "");
  return `max-width:${escapeAttr(w)}%;`;
}

function parseIncludeAttrs(raw) {
  const attrs = {};
  let text = String(raw || "");
  // Allow newlines inside quoted values (dict-card def=, tweet body=/note=).
  text = text.replace(
    /([\w-]+)\s*=\s*(?:"([\s\S]*?)"|'([\s\S]*?)')/g,
    (_, key, dbl, sgl) => {
      attrs[key] = dbl != null ? dbl : sgl;
      return "";
    }
  );
  text.replace(/([\w-]+)\s*=\s*([^\s%]+)/g, (_, key, val) => {
    if (!(key in attrs)) attrs[key] = val;
    return "";
  });
  return attrs;
}

function figureHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return "";
  const width = maxWidthCss(attrs.width);
  const caption = attrs.caption || "";
  return [
    `<figure class="my-8 mx-auto text-center w-full" style="display:block;${width}">`,
    `<img class="figure-lightbox-trigger" src="${escapeAttr(src)}" alt="${escapeAttr(attrs.alt || caption)}" loading="lazy">`,
    caption ? `<figcaption class="mt-3">${escapeHtml(caption)}</figcaption>` : "",
    "</figure>",
  ].join("");
}

function cutInHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return "";
  const sideClass = attrs.side === "right" ? " article-cut-in--right" : "";
  return `<figure class="article-cut-in-plate${sideClass}"><img class="article-cut-in${sideClass}" src="${escapeAttr(src)}" alt="${escapeAttr(attrs.alt || "")}" width="120" loading="lazy"></figure>`;
}

/** Basename for labels (`/media/plots/goo.html` → `goo.html`). */
function fileLabel(path) {
  const raw = unwrapMediaSrc(path);
  if (!raw) return "";
  const cleaned = raw.split(/[?#]/)[0];
  const parts = cleaned.split(/[/\\]/).filter(Boolean);
  return parts[parts.length - 1] || cleaned;
}

/** YouTube id from bare id or embed/watch/shorts URL. */
function youtubeIdFrom(value) {
  const raw = unwrapMediaSrc(value);
  if (!raw) return "";
  const m = raw.match(
    /(?:youtube\.com\/(?:embed\/|shorts\/|watch\?v=)|youtu\.be\/)([A-Za-z0-9_-]{6,})/
  );
  if (m) return m[1];
  if (/^[A-Za-z0-9_-]{6,}$/.test(raw)) return raw;
  return raw;
}

/**
 * Sized rectangle for embeds Studio must not load live (Plotly HTML, YouTube, video).
 * Images stay real; this is for network / heavy external media only.
 */
function embedPlaceholderHtml(label, { width, height, aspect, caption } = {}) {
  const text = String(label || "").trim() || "Embed";
  const styleParts = [maxWidthCss(width)];
  if (height) styleParts.push(`min-height:${escapeAttr(String(height))}px`);
  else if (aspect) styleParts.push(`aspect-ratio:${escapeAttr(aspect)}`);
  else styleParts.push("min-height:12rem");
  const fig = [
    `<figure class="studio-embed-placeholder" style="display:block;margin:1.5rem auto;text-align:center;${styleParts.join("")}">`,
    `<div class="studio-embed-placeholder__box" role="img" aria-label="${escapeAttr(text)}">`,
    `<code class="studio-embed-placeholder__label">${escapeHtml(text)}</code>`,
    `</div>`,
  ];
  if (caption) fig.push(`<figcaption>${escapeHtml(caption)}</figcaption>`);
  fig.push("</figure>");
  return fig.join("");
}

function youtubeHtml(attrs) {
  const id = youtubeIdFrom(attrs.id || attrs.src);
  if (!id) return "";
  return embedPlaceholderHtml(`YouTube video: ${id}`, {
    width: attrs.width,
    aspect: "16 / 9",
    caption: attrs.caption,
  });
}

function youtubeShortHtml(attrs) {
  const id = youtubeIdFrom(attrs.src || attrs.id);
  if (!id) return "";
  const id2 = youtubeIdFrom(attrs.src2 || attrs.id2);
  if (id2) {
    return [
      embedPlaceholderHtml(`YouTube short: ${id}`, {
        width: "45",
        aspect: "9 / 16",
      }),
      embedPlaceholderHtml(`YouTube short: ${id2}`, {
        width: "45",
        aspect: "9 / 16",
      }),
    ].join("");
  }
  return embedPlaceholderHtml(`YouTube short: ${id}`, {
    width: attrs.width || "45",
    aspect: "9 / 16",
  });
}

function videoHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return "";
  const label = fileLabel(src) || src;
  return embedPlaceholderHtml(`Video: ${label}`, {
    width: attrs.width,
    aspect: "16 / 9",
    caption: attrs.caption,
  });
}

function plotlyHtml(attrs) {
  const src = unwrapMediaSrc(attrs.src);
  if (!src) return "";
  const name = fileLabel(src) || src;
  return embedPlaceholderHtml(`Plotly: ${name}`, {
    width: attrs.width,
    height: attrs.height || "480",
    caption: attrs.caption,
  });
}

/**
 * Shared preview pill (cite / xcite / latex). One box — no nested wrappers.
 * main.js paints cite/xcite green/red after debounced existence check.
 */
function pillHtml(text, { kind, key, variant, display } = {}) {
  const label = String(text || "").trim() || "?";
  const classes = ["studio-ref-pill"];
  if (variant) classes.push(`studio-ref-pill--${variant}`);
  if (display) classes.push("studio-ref-pill--display");
  const attrs = [`class="${classes.join(" ")}"`];
  if (kind) {
    attrs.push(`data-cite-check="${escapeAttr(kind)}"`);
    attrs.push(`data-key="${escapeAttr(String(key || "").trim())}"`);
  }
  if (variant === "latex") {
    attrs.push('title="LaTeX (MathJax not available in Studio preview)"');
  }
  return `<span ${attrs.join(" ")}>${escapeHtml(label)}</span>`;
}

function refPillHtml(kind, key) {
  const k = String(key || "").trim();
  return pillHtml(k || "?", { kind, key: k });
}

function xciteHtml(attrs) {
  return refPillHtml("xcite", attrs.key);
}

function citeHtml(attrs) {
  return refPillHtml("cite", attrs.key);
}

function formatDefHtml(def) {
  return escapeHtml(String(def || "").trim()).replace(/\r\n|\r|\n/g, "<br>");
}

/** Side-preview for `_includes/dict-card.html` (content-runtime–aligned). */
function dictCardHtml(attrs) {
  const lemma = String(attrs.lemma || "").trim();
  if (!lemma) return "";
  const locale = String(attrs.locale || "").trim().toLowerCase();
  const meta = String(attrs.meta || "").trim();
  const label = String(attrs.country || meta || locale).trim();
  const note = String(attrs.note || "").trim();
  const source = String(attrs.source || "").trim();
  const url = String(attrs.url || "").trim();
  const accessed = String(attrs.accessed || "").trim();
  const citeExtra = String(attrs.cite_extra || "").trim();
  const linkLabel = String(attrs.link_label || url).trim();
  const parts = [
    `<article class="sov-card${locale ? ` sov-card--${escapeAttr(locale)}` : ""}" role="listitem">`,
    `<div class="sov-card__head">`,
  ];
  if (locale) {
    parts.push(
      `<span class="sov-card__flag" title="${escapeAttr(label)}">` +
        `<span class="fi fi-${escapeAttr(locale)}" role="img" aria-label="${escapeAttr(label)}"></span>` +
        `</span>`
    );
  }
  if (meta) {
    parts.push(`<span class="sov-card__meta">${escapeHtml(meta)}</span>`);
  }
  parts.push(`</div>`);
  parts.push(`<p class="sov-card__lemma">${escapeHtml(lemma)}</p>`);
  if (attrs.def) {
    parts.push(`<div class="sov-card__def">${formatDefHtml(attrs.def)}</div>`);
  }
  if (note) {
    // Note may carry intentional inline HTML (e.g. <em>), matching site Liquid.
    parts.push(`<p class="sov-card__note">${note}</p>`);
  }
  if (source) {
    let cite =
      `${escapeHtml(source)}, s.v. &ldquo;${escapeHtml(lemma)},&rdquo;`;
    if (url) {
      cite += ` <a href="${escapeAttr(url)}">${escapeHtml(linkLabel)}</a>`;
    }
    if (accessed) cite += `, accessed ${escapeHtml(accessed)}`;
    cite += ".";
    if (citeExtra) cite += ` ${escapeHtml(citeExtra)}`;
    parts.push(`<p class="sov-card__cite">${cite}</p>`);
  }
  parts.push(`</article>`);
  return parts.join("");
}

/** Wrap runs of dictionary cards in the same grid the public runtime uses. */
function wrapDictCardGrid(html) {
  return String(html || "").replace(
    /(?:<article\b[^>]*\bsov-card\b[\s\S]*?<\/article>\s*){2,}/g,
    (block) => {
      if (/\bsov-grid\b/.test(block)) return block;
      return `<div class="sov-grid" role="list">${block.trim()}</div>\n`;
    }
  );
}

function tweetHtml(attrs) {
  const body = String(attrs.body || "").trim();
  if (!body) return "";
  const handle = String(attrs.handle || "")
    .trim()
    .replace(/^@/, "");
  const icon = String(attrs.icon || "chat").trim() || "chat";
  const url = String(attrs.url || "").trim();
  const date = String(attrs.date || "").trim();
  const note = String(attrs.note || "").trim();
  const name = String(attrs.name || "").trim();
  const linkLabel = url.replace(/^https?:\/\//, "");
  const parts = [
    `<article class="sov-tweet article-tweet">`,
    `<div class="sov-tweet__head article-tweet__head">`,
    `<span class="sov-tweet__avatar article-tweet__avatar" aria-hidden="true"><span class="material-symbols-outlined">${escapeHtml(icon)}</span></span>`,
    `<span class="sov-tweet__id article-tweet__id">`,
  ];
  if (name) {
    parts.push(
      `<span class="sov-tweet__name article-tweet__name">${escapeHtml(name)}</span>`
    );
  }
  if (handle) {
    parts.push(
      `<span class="sov-tweet__handle article-tweet__handle">@${escapeHtml(handle)}</span>`
    );
  }
  parts.push(`</span></div>`);
  // Body/note may carry intentional inline HTML (e.g. <em>), matching site runtime.
  // Local card only — no X/Twitter widget script.
  parts.push(`<p class="sov-tweet__body article-tweet__body">${body}</p>`);
  if (url || date) {
    let cite = "";
    if (url) cite += `<a href="${escapeAttr(url)}">${escapeHtml(linkLabel)}</a>`;
    if (url && date) cite += " | ";
    if (date) cite += escapeHtml(date);
    parts.push(`<p class="sov-tweet__cite article-tweet__cite">${cite}</p>`);
  }
  if (note) {
    parts.push(`<p class="sov-tweet__note article-tweet__note">${note}</p>`);
  }
  parts.push(`</article>`);
  return parts.join("");
}

function articleNoteHtml(innerMarkdown) {
  const inner = String(innerMarkdown || "").trim();
  if (!inner) return `<div class="article-note"></div>`;
  let bodyHtml = "";
  try {
    bodyHtml = marked.parse(inner, { gfm: true, breaks: false });
  } catch {
    bodyHtml = `<p>${escapeHtml(inner)}</p>`;
  }
  return `<div class="article-note">${bodyHtml}</div>`;
}

function latexPillHtml(tex, display) {
  return pillHtml(String(tex || "").trim(), {
    variant: "latex",
    display: Boolean(display),
  });
}

function normalizeDisplayMathTex(math) {
  // Keep light parity with scripts/lib/normalize-display-math.mjs (row breaks).
  return String(math || "").replace(/\\\s/g, "\\\\ ");
}

function protectMath(markdown) {
  const store = [];
  let text = String(markdown || "");
  const push = (display, math) => {
    const i = store.length;
    store.push({ display, math });
    return `\uE000MATH${i}\uE001`;
  };
  text = text.replace(/\$\$([\s\S]+?)\$\$/g, (_, math) =>
    push(true, normalizeDisplayMathTex(math))
  );
  text = text.replace(/\\\[([\s\S]+?)\\\]/g, (_, math) =>
    push(true, normalizeDisplayMathTex(math))
  );
  text = text.replace(/\\\(([\s\S]+?)\\\)/g, (_, math) => push(false, math));
  text = text.replace(
    /(^|[^\\$])\$(?!\$)([^$\n]+?)\$(?!\$)/g,
    (match, prefix, math) => prefix + push(false, math)
  );
  return { text, store };
}

function restoreMathAsPills(html, store) {
  return String(html || "").replace(/\uE000MATH(\d+)\uE001/g, (_, idx) => {
    const entry = store[Number(idx)];
    if (!entry) return "";
    return latexPillHtml(entry.math, entry.display);
  });
}

const RENDERERS = {
  "figure.html": figureHtml,
  "cut-in.html": cutInHtml,
  "youtube.html": youtubeHtml,
  "youtube-short.html": youtubeShortHtml,
  "video.html": videoHtml,
  "plotly.html": plotlyHtml,
  "xcite.html": xciteHtml,
  "cite.html": citeHtml,
  "dict-card.html": dictCardHtml,
  "tweet.html": tweetHtml,
};

export function preprocessIncludes(markdown) {
  let text = String(markdown || "");

  // Block article-note include (Studio TipTap / Liquid body form).
  text = text.replace(
    /\{%-?\s*include\s+article-note(?:\.html)?\b(?:(?!%\})[\s\S])*?-?%\}\s*([\s\S]*?)\s*\{%-?\s*endinclude\s*-?%\}/gi,
    (_, body) => articleNoteHtml(body)
  );

  // Authored HTML callout (most published articles/posts).
  text = text.replace(
    /<div\s+([^>]*\barticle-note\b[^>]*)>([\s\S]*?)<\/div>/gi,
    (_, _open, inner) => articleNoteHtml(inner)
  );

  // Bibliography cite tag used in published Markdown: {% cite key %}
  text = text.replace(
    /\{%-?\s*cite\s+([^\s%]+)[\s\S]*?-?%\}/g,
    (_, key) => refPillHtml("cite", key)
  );

  // Stop at `%}` only — attrs often contain `%` (width="80%", percent-encoded URLs).
  text = text.replace(
    /\{%-?\s*include\s+([\w.-]+)\s*((?:(?!%\})[\s\S])*?)\s*-?%\}/g,
    (_, name, rawAttrs) => {
      const renderer = RENDERERS[name];
      if (!renderer) {
        return `<div class="studio-unknown-include" data-include="${escapeAttr(name)}"></div>`;
      }
      return renderer(parseIncludeAttrs(rawAttrs));
    }
  );
  return text;
}

export function renderPreview(markdown) {
  const math = protectMath(String(markdown || ""));
  const pre = preprocessIncludes(math.text);
  let html;
  try {
    html = marked.parse(pre, { gfm: true, breaks: false });
  } catch {
    html = `<p>${escapeHtml(pre)}</p>`;
  }
  return wrapDictCardGrid(restoreMathAsPills(html, math.store));
}
