# Marked ready before markdown render

## Intent

The markdown library (`marked`) loads with `defer` so it does not block first
paint (PLT-AC-23). The content runtime is an inline script that runs during
HTML parse and fires `pandorga:runtime` before deferred scripts execute. When
content JSON resolves quickly (preload, HTTP cache, or a fast object store)
`renderMarkdown` can run while `window.marked` is still undefined. Today's
fallback escapes the raw markdown into `<p>` tags, so the article body shows
literal `##` headings, `{% include figure.html %}`, mermaid fences, and `$$`
with no re-render once `marked` arrives. Production R2 latency often hides
the race; a slow jsDelivr response or a warm JSON cache exposes it.

## Scope

In:

- Waiting for `marked` before any path that paints markdown HTML into the
  page (detail bodies, page fragments, home early paint, CV job bodies).
- Keeping the markdown library on `defer` for Lighthouse.
- Refusing a silent escaped-raw fallback for painted HTML.

Out:

- Changing the CDN pin or bundling `marked` into the shell.
- MathJax / mermaid load order (they already gate on their own promises).
- Listing plain-text excerpts that never paint markdown HTML.

## Acceptance criteria

- `PLT-AC-107` Marked ready before paint.
  1. **Defer stays.** `marked@15.0.7/marked.min.js` still loads with
     `<script defer>` (`test-lighthouse-policy`, `test-marked-ready`).
  2. **Ready gate.** The runtime exposes `ensureMarked()` that resolves only
     after `window.marked.parse` exists. A deferred companion script after
     the library script resolves the gate once `marked` has run
     (`test-marked-ready`).
  3. **Paint waits.** `renderRichContent`, `mountMarkdownFragment`, the home
     early-paint path, and CV job markdown rendering await `ensureMarked`
     before calling `renderMarkdown` (`test-marked-ready`).
  4. **No silent raw HTML.** When `marked` is missing, `renderMarkdown` and
     `parseInlineMarkdown` must not escape the source into painted `<p>`
     blocks; they fail closed instead of showing raw markdown
     (`test-marked-ready`).

## Verification

`scripts/test/test-marked-ready.rb` locks the wiring. Live reproduction with
a delayed `marked` CDN response against an article URL shows a sticky raw
body before the fix and a rendered body after it.
