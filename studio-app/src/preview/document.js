/**
 * Builds the full HTML document mounted into the article/post preview
 * `<iframe>`. Loads the real site stylesheets so body typography, spacing,
 * figures, and links render byte-for-byte the way the published page does —
 * `renderPreview()` (./render.js) still owns the markdown → HTML step; this
 * module only owns the page shell around it.
 *
 * DOM shape mirrors `_layouts/text.html`'s detail column exactly (including
 * the empty `<aside>`, since `ledger/detail.css` gives the reading column a
 * `minmax(0, 1fr)` grid track only when a sibling column is present at
 * desktop widths — drop the aside and the column measures wrong above
 * 768px).
 */
import { PREVIEW_FONTS_HREF, ARTICLE_THEME_TOKENS_CSS } from "./theme-tokens.js";

const SITE_STYLESHEETS = [
  "/assets/css/base.css",
  "/assets/css/global-link.css",
];

// `ledger/detail.css` and `article.css` own body/column sizing and are
// static (not theme-dependent), so the token `<style>` block only needs to
// land after the two sheets above and before these — same order as
// `_layouts/shell.html`.
const CONTENT_STYLESHEETS = [
  "/assets/css/article.css",
  "/assets/css/ledger/detail.css",
  // Not in the literal 4-sheet list, but `_layouts/text.html`'s outer
  // `max-w-7xl / px-4 sm:px-8 md:px-16` column padding is Tailwind
  // utilities, not `ledger/detail.css` — the mobile (390px) reading
  // column measures wrong without it. Pre-built, checked-in sheet, not a
  // CDN script (scripts/tailwind/build.sh); no build step added here.
  "/assets/css/tailwind.css",
];

function escapeHtmlAttr(value) {
  return String(value ?? "").replace(/"/g, "&quot;");
}

/**
 * @param {{ theme: "light" | "dark" }} options
 * @returns {string} full `<html>…</html>` document for `iframe.srcdoc`.
 */
export function buildArticlePreviewShellHtml({ theme } = {}) {
  const dataTheme = theme === "dark" ? "dark" : "light";
  const siteLinks = SITE_STYLESHEETS.map(
    (href) => `<link rel="stylesheet" href="${escapeHtmlAttr(href)}">`
  ).join("\n");
  const contentLinks = CONTENT_STYLESHEETS.map(
    (href) => `<link rel="stylesheet" href="${escapeHtmlAttr(href)}">`
  ).join("\n");

  return `<!doctype html>
<html lang="en" data-theme="${dataTheme}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="${escapeHtmlAttr(PREVIEW_FONTS_HREF)}">
${siteLinks}
<style id="preview-theme-tokens">${ARTICLE_THEME_TOKENS_CSS}</style>
${contentLinks}
<style>
  /* Preview-only: the real shell's topbar/footer do not exist here, and
     without them the html-body fixed background grid from base.css would
     scroll the reading column against a static backdrop that never
     matches the page it is lifted from. */
  html, body { background-color: var(--color-canvas); }
</style>
</head>
<body class="bg-background text-on-surface">
<div class="max-w-7xl mx-auto px-4 sm:px-8 md:px-16 py-12 text-page" id="preview-page">
  <div class="grid grid-cols-1 gap-8 lg:gap-12 items-start text-detail-grid">
    <aside class="text-detail-sidebar" id="preview-article-header">
      <div class="article-sidebar-heading">
        <div class="ledger-chip-row" id="preview-tags"></div>
        <h1 class="text-title" id="preview-title"></h1>
        <p class="article-sidebar-description" id="preview-standfirst"></p>
      </div>
      <div class="article-meta">
        <div class="date-evolution" id="preview-dates"></div>
      </div>
    </aside>
    <div class="text-detail-main">
      <div class="text-reading-column text-page-main" data-detail-view>
        <div class="article-content" id="preview-article-content"></div>
      </div>
    </div>
  </div>
</div>
</body>
</html>
`;
}
