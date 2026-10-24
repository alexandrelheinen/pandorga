# Canvas and card layout

## Intent

Make the home page, the listing pages and the reading view easier to scan on a phone without changing the identity of the theme. The page becomes one ground (the canvas) with square cards on it, each section opens with a compact header, the type steps down on small screens, and the decoration that competed with the content goes away. The palette, the page accents, the fonts, the highlighter marks, the icons, the illustrations, the project button navigation and the footer stay as they are.

## Scope

In:

- One canvas behind every page, from a new `--color-canvas` token.
- Cards on the canvas: card surface, 1px hairline, square corners, no shadow. Featured cards open on a 2px accent rule.
- Compact home band header: title and "View all" on one row, the note under them.
- Smaller phone type for home band titles, card titles, excerpts and metadata. Metadata in the mono face.
- Excerpts clamped to 3 lines below 768px and 4 lines from 768px.
- Phone layouts for the featured article (image first, edge to edge), the Rascunhos grid (two columns, no tilt), the Sources / Network / Bibliography panels (title and Open, then the illustration) and the project cards (posters edge to edge).
- Top bar on the translucent canvas with a hairline, and the theme and menu buttons as bordered square boxes.
- Reading view without a box on phones; the dossier and the reading column become cards from 768px.
- Text calls to action ("View all", "Open", "Read", "Repository", "Article") carry the highlighter mark instead of an underline.
- Removal of the radial blur pools and of the decorative shards outside the footer, and of the frame corners inside cards.

Out:

- Palette values, page accents, fonts and font weights, prose size and leading.
- The footer, including its shards and the bottom strip.
- The hero name size and the hero portrait frame (`PLT-AC-39`, `PLT-AC-40`, hero name feature).
- Mark strengths, mark variants and the tag hierarchy (`PLT-AC-46`).
- Project button navigation (`PLT-AC-41`) and the band art drawings.
- A fixed bottom tab bar. There is none.
- Image corner marks drawn by `.ledger-poster::after` on posters.

## Acceptance criteria

- `PLT-AC-49` The theme draws one canvas with square hairline cards, compact band headers, a smaller phone type scale and highlighter-marked text calls to action. Each item names the gate section that checks it (`test-v3-layout`; `test-shell-a11y` for 4; `test-theme-contrast` for 12):
  1. **Canvas.** The theme shall emit `--color-canvas` for each palette, from `neutrals.canvas`, else `neutrals.panel_contrast`. `html body` shall paint `background-color: var(--color-canvas)`. The hero band and the contrast bands shall be transparent (`background-color: transparent`), so every home band shows the canvas. No rule in `base.css`, and no index panel (8) or project bench (10) rule, shall use `--color-surface-card-contrast` or `--color-surface-high-contrast`.
  2. **Cards.** `.ledger-card` and `.ledger-system-card` shall use `background: var(--color-surface-card)` and `border: 1px solid var(--border-ink)` in both themes, with `border-radius: var(--radius-card)`; the light-only 1px override rule shall be removed. `.home-featured` shall use the same background and border, with `border-top: 2px solid var(--color-primary)`.
  3. **Decoration.** `home.css` shall carry no radial blur pool (no `radial-gradient(` and no `filter: blur(`). No layout or include other than `_includes/page/site-footer.html` and `_includes/home/band-index.html` (see 8) shall render a `shard-accent` element, and the CSS rules for the removed shard classes shall be deleted. The project card renderer shall not emit `ledger-frame-corners`.
  4. **Top bar.** The top bar shall be `<header class="site-topbar sticky top-0 z-50">` without the tonal separator `div`. `.site-topbar` shall paint `color-mix(in srgb, var(--color-canvas) 92%, transparent)` with `backdrop-filter: blur(10px)` (and the `-webkit-` form) and `border-bottom: 1px solid var(--border-gentle-divider)`. `#theme-toggle-btn` and `#mobile-menu-btn` shall be 2.25rem squares with `border: 1px solid var(--color-outline-variant)`, `background-color: var(--color-surface-card)` and `color: var(--color-on-surface)`. The logo stays left and the menu right.
  5. **Band header.** In a home band other than the hero, `.ledger-section-banner` shall be a grid with `grid-template-columns: minmax(0, 1fr) auto`; `.home-band .ledger-section-lead` shall be `display: contents`; the kicker shall span row 1, the title shall sit in row 2, column 1, the aside ("View all") in row 2, column 2, and the note in row 3 across both columns. An empty kicker shall not take a row. `.home-band .ledger-section-banner .section-title` shall be `var(--type-section-sm)` below 768px and `var(--type-section)` from 768px; `.home-band .home-section-note` shall be `var(--type-dek)` below 768px.
  6. **Card type.** `.ledger-meta` shall use `var(--font-mono)`, `letter-spacing: 0` and `var(--type-micro)`. `.card-title` and `.ledger-card-title` shall use `var(--weight-emphasis)`; below 768px they shall be `var(--type-card-sm)` at line height 1.25. Below 768px `.ledger-card-body` and `.ledger-system-card` shall pad `var(--space-md)`. `.ledger-card-copy` shall clamp to 3 lines (`-webkit-line-clamp` and `line-clamp`) and to 4 lines from 768px, at `var(--type-dek)` below 768px.
  7. **Featured article.** Below 768px `.home-featured` shall be a flex column with `padding: 0`; its poster (`.home-featured > .ledger-poster`) shall come first (`order: -1`), full width, `aspect-ratio: 16 / 9`, with no margin or border; `.home-featured-lead` shall pad `var(--space-md)`. `.home-featured-copy` shall clamp to 3 lines, and 4 from 768px.
  8. **Index panels.** In `band-index.html` each `.home-index-panel` shall open with a `.home-index-panel-head` that holds the `h3.home-index-title` and the Open link, followed by the `figure.home-index-plate`, and shall render no shard. `.home-index-panel` shall have `padding: 0`, `gap: 0`, `background: var(--color-surface-card)` and `border: 1px solid var(--border-ink)`; `.home-index-panel-head` shall be a flex row (`justify-content: space-between`, `align-items: center`) padded `var(--space-sm) var(--space-md)`; `.home-index-plate` shall have `border-top: 1px solid var(--border-gentle-divider)`. No rule shall style `.home-index-shard`.
  9. **Rascunhos.** No home rule shall rotate a draft card (`rotate(` does not appear in `home.css`). Below 768px `.home-draft-card .ledger-poster` shall be `aspect-ratio: 4 / 3`, `.home-draft-card .ledger-meta` shall stay on one line (`flex-wrap: nowrap`, `white-space: nowrap`, `overflow: hidden`), `.home-draft-card .ledger-card-title` shall be `var(--type-dek)` and `.home-draft-card .ledger-card-copy` `var(--type-label)`. `.home-draft-card .ledger-card-title` shall clamp to 3 lines. `.home-draft-card .ledger-card-copy` shall clamp to 3 lines, and 4 from 768px; no rule shall clamp it to 5 or 6.
  10. **Projects.** `.home-project-inventory-row` and `.home-project-specimen` shall use `background: var(--color-surface-card)` and `border: 1px solid var(--border-ink)` (the specimen keeps its 2px primary top rule). `.projects-page .projects-lead` shall use `border: 1px solid var(--border-ink)` and `border-top: 2px solid var(--color-primary)`, with no left rule. Below 768px `.projects-page .projects-lead-body` shall pad `var(--space-md)`, `.projects-page .projects-grid` shall gap `var(--space-md)`, and the project card poster (`.projects-page .ledger-system-card>.ledger-poster`) shall pull out by `var(--space-md)` so it runs edge to edge. The project button navigation is unchanged (`PLT-AC-41`).
  11. **Reading view.** From 768px `.text-detail-sidebar`, its heading and its meta block shall paint `var(--color-surface-card)` instead of `var(--color-panel-contrast)`, and `.text-page-main` shall paint `var(--color-surface-card)` with `border: 1px solid var(--border-ink)`. Below 768px `.text-detail-sidebar`, `.text-detail-sidebar .article-sidebar-heading`, `.text-detail-sidebar .article-meta` and `.text-page-main` shall be transparent with `border: 0`, and `.text-page-main` shall have `padding: 0`. Prose rules are unchanged.
  12. **Text calls to action.** A `.ledger-cta` that is neither `--emphasis` nor `--emphasis-alt` shall carry the shared highlighter mark at the strong strength (`--mark-strong-a/b/c`), the hover strength on hover, and text in `color-mix(in srgb, var(--color-primary) var(--action-ink-mix), var(--color-on-surface))`. No `.ledger-cta` rule shall set `text-decoration: underline`. The selector is `.ledger-cta:where(:not(.ledger-cta--emphasis):not(.ledger-cta--emphasis-alt))`, so its specificity stays that of `.ledger-cta` and page rules such as the featured Read solid mark keep winning. Its text shall reach 4.5:1 on the strong and hover mark heads over the background, surface, card and canvas steps of both palettes.
  13. **Guards.** No stylesheet shall gain an `!important`.

## Design notes

The canvas is the panel-contrast step, which already exists in both palettes, so cards on the canvas use the card surface (white in light, the background step in dark) and need no new colour. The band header uses `display: contents` on the lead column so the markup, and the runtime that fills the kicker, title and note slots (`PLT-AC-42`), stay as they are. The text call-to-action mark joins the shared mark rule from `PLT-AC-46` through a zero-specificity `:where()`, which is why existing page-level CTA treatments, such as the solid Read mark, keep precedence without new overrides.

## Constraints

Tokens only: no colour literals, so both palettes keep working. No `!important`. No Node build for the public shell. Markup changes are limited to the top bar, the index band and the removed decoration spans; listing slots and runtime hooks keep their names.
