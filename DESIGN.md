---
version: "2.0"
name: "Brazilian Ledger"
description: >-
  Editorial-brutalist personal site, rebuilt on the "Architectural Ledger"
  component layer. Pure-white (or near-black) paper, square cards with thin
  clear ink frames (Reimagined Borders), a slate/forest/ochre triad with
  raised chroma (2026-09 vivid pass), serif display titles over a humanist
  sans body, monospace for notation, and translucent "cubist shards" reduced
  to two canonical polygons. Depth is a four-step surface ladder — canvas,
  panel, card, hover — rather than shadow. Every card, row, chip, meta strip
  and CTA comes from one shared JavaScript block library. Two complete
  palettes, light and dark, selected by data-theme on <html>.
omitted:
  - name: "Elevation"
    reason: >-
      Deliberate. Content carries no shadow at all; the only two box-shadows
      in the build are on floating overlays. Depth is the surface ladder plus
      hairline borders.

# ─────────────────────────────────────────────────────────────
# Colors. Two full palettes. Source of truth: _data/themes/*.yml
# rendered into CSS custom properties by _includes/theme/theme-vars-block.liquid.
# Light is also bound to :root, so it is the no-JS default.
# ─────────────────────────────────────────────────────────────
colors:
  light:
    primary: "#1c5a7a"                    # ice slate (vivid 2026-09)
    secondary: "#287445"                  # forest green (vivid 2026-09)
    tertiary: "#746f30"                   # ochre gold (vivid 2026-09)
    primaryContainer: "#a8c5d4"
    secondaryContainer: "#b4d4c0"
    tertiaryContainer: "#d0ceb0"
    onPrimaryContainer: "#0a1419"
    onSecondaryContainer: "#0c1710"
    onTertiaryContainer: "#17160c"
    onPrimary: "#ffffff"
    onSecondary: "#ffffff"
    onTertiary: "#ffffff"
    # ── The Architectural Ledger surface ladder ──
    # White-paper edition 2026-09: canvas is pure #ffffff. Cards rest
    # transparent (panel/canvas and shards show through) and take a fill
    # only on hover. Panel contrast is near-neutral grey (#f4f4f4) — cream
    # pulled ochre, blue-grey still read as slate; equal-RGB greys keep the
    # ladder quiet. Stitch alabaster #fcf9f6 is deliberately not used
    # (yellow cast on printed CV).
    #
    # The triad keeps the Ledger hues (slate / forest / ochre) with higher
    # chroma — Stitch inspires vividness, it does not replace the system.
    background: "#ffffff"                 # step 1 — canvas, white paper
    backgroundSecondary: "#f4f4f4"
    panelContrast: "#f4f4f4"              # step 2 — panel / alternating band
    surfaceCard: "transparent"            # step 3 — card at rest (no fill)
    surfaceCardContrast: "transparent"    # step 3b — same on contrast panel
    surfaceHigh: "#ebebeb"                # step 4 — hover
    surfaceHighContrast: "#e2e2e2"        # step 4b — hover on contrast card
    # ── The older Material surface ramp, still emitted and still used ──
    surface: "#ffffff"
    surfaceContainerLowest: "#ffffff"
    surfaceContainerLow: "#f4f4f4"
    surfaceContainer: "#ebebeb"
    surfaceContainerHigh: "#e2e2e2"
    surfaceContainerHighest: "#d8d8d8"
    surfaceVariant: "#d8d8d8"
    surfaceDim: "#d8d8d8"
    panelGrey: "#f1f1f1"                  # color-mix(surfaceContainer 82%, background)
    onSurface: "#000000"
    onSurfaceVariant: "#5e5d59"
    onBackground: "#000000"
    outline: "#5c5c5c"
    outlineVariant: "#b8b8b8"             # every hairline is an opacity step of this
    link: "#1c5a7a"
    linkHover: "#2a6f92"
    inversePrimary: "#a4c8da"
    inverseSurface: "#303030"
    inverseOnSurface: "#f2f2f2"
    error: "#ba1a1a"
    onError: "#ffffff"
    errorContainer: "#ffdad6"
    onErrorContainer: "#93000a"
    resYoutube: "#c62828"
    resPodcast: "#2e7d32"
    resDoc: "#b45309"
    chartProject: "#6fb387"
    sidebarThumbnailBackground: "#ebebeb"
  dark:
    primary: "#9dc2d6"
    secondary: "#8fc29f"
    tertiary: "#d7d4a5"
    primaryContainer: "#475760"
    secondaryContainer: "#405748"
    tertiaryContainer: "#67664f"
    onPrimaryContainer: "#b6d1e0"
    onSecondaryContainer: "#abd1b7"
    onTertiaryContainer: "#e1dfbc"
    onPrimary: "#0f1a22"
    onSecondary: "#141a15"
    onTertiary: "#1b1c12"
    # ── The Architectural Ledger surface ladder ──
    # Re-based 2026-09 in two moves. First, neutralised: the old values had G
    # as the highest channel across the whole ladder, which read as an
    # olive/green cast rather than black. Then widened: panel and hover keep
    # the ~+4 / ~+6 L* steps; resting cards are transparent so shards and
    # the panel show through. Vivid 2026-09: triad chroma raised.
    background: "#0c0c0e"                 # step 1 — canvas, near-black, neutral
    panelContrast: "#141418"              # step 2 — panel / alternating band
    surfaceCard: "transparent"            # step 3 — card at rest (no fill)
    surfaceHigh: "#26262b"                # step 4 — hover, chip fill
    # ── The older Material surface ramp, still emitted and still used ──
    backgroundSecondary: "#141418"
    surface: "#111114"                    # distinct from background in dark
    surfaceContainerLowest: "#08080a"
    surfaceContainerLow: "#17171b"
    surfaceContainer: "#1f1f24"
    surfaceContainerHigh: "#26262b"
    surfaceContainerHighest: "#33342e"    # documented here only — not a field in dark.yml
    surfaceVariant: "#2e2e34"
    surfaceDim: "#060607"
    panelGrey: "#22231f"                  # documented here only — not a field in dark.yml
    onSurface: "#ffffff"
    onSurfaceVariant: "#b8b7ae"
    onBackground: "#ffffff"
    outline: "#93938d"
    outlineVariant: "#45454c"             # neutralised 2026-09; every hairline is an opacity step of this
    link: "#a9cbdc"
    linkHover: "#bfd7e4"
    inversePrimary: "#255b75"
    inverseSurface: "#e8e6e1"
    inverseOnSurface: "#141413"
    error: "#ffb4ab"
    onError: "#690005"
    errorContainer: "#93000a"
    onErrorContainer: "#ffdad6"
    resYoutube: "#de6461"
    resPodcast: "#5dc462"
    resDoc: "#e4b268"
    chartProject: "#90c0a3"
    sidebarThumbnailBackground: "#1f1f24"

# Borders are never a raw color. They are opacity steps of outlineVariant
# (gentle ladder) plus denser ink-frame mixes of onSurface for sketchbook
# cards (--border-ink / --border-ink-strong), identical token names in both
# themes.
borders:
  gentleFaint: "color-mix(in srgb, {colors.*.outlineVariant} 22%, transparent)"
  gentleSubtle: "color-mix(in srgb, {colors.*.outlineVariant} 32%, transparent)"
  gentleDivider: "color-mix(in srgb, {colors.*.outlineVariant} 35%, transparent)"
  gentle: "color-mix(in srgb, {colors.*.outlineVariant} 62%, transparent)"
  gentleHover: "color-mix(in srgb, {colors.*.outlineVariant} 78%, transparent)"
  ink: "color-mix(in srgb, {colors.*.onSurface} 72%, transparent)"
  inkStrong: "color-mix(in srgb, {colors.*.onSurface} 88%, transparent)"

# ─────────────────────────────────────────────────────────────
# Typography. Root font-size is 110%, so 1rem ≈ 17.6px.
# Faces live once in `_data/themes/shared.yml` (not per colour theme).
# ─────────────────────────────────────────────────────────────
typography:
  fontFamilies:
    title: "'Cinzel Decorative', serif"
    subtitle: "'Newsreader', serif"
    label: "'Marcellus SC', serif"
    body: "'Newsreader', sans-serif"
    mono: "'Courier Prime', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace"
    code: "'Courier Prime', ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace"
  rootFontSize: "110%"

  pageTitle:                              # 404 only; the home hero no longer uses it
    fontFamily: "{typography.fontFamilies.title}"
    fontSize: "2.75rem"
    fontSizeMd: "3.75rem"
    fontWeight: 400
  homeHeroTitle:                          # copy-column cqi; floor is the band title
    fontFamily: "{typography.fontFamilies.title}"
    fontSize: "clamp(var(--type-section), calc(100cqi * 0.92 / 14.5), var(--type-page-lg))"
    fontSizeSm: "clamp(var(--type-section-lg), calc(100cqi * 0.92 / 14.5), var(--type-page-lg))"  # ≥640px, same step as sectionTitle
    fontWeight: 400
  pageHeaderTitle:                        # listing pages
    fontFamily: "{typography.fontFamilies.title}"
    fontSize: "2.35rem"
    fontSizeMd: "2.85rem"
    fontWeight: 400
  textTitle:                              # article / post detail title
    fontFamily: "{typography.fontFamilies.subtitle}"
    fontSize: "1.95rem"
    fontSizeMd: "2.45rem"
    fontWeight: 400
  sectionTitle:                           # band headers, register rails, banners
    fontFamily: "{typography.fontFamilies.title}"
    fontSize: "1.75rem"
    fontSizeSm: "2.05rem"
    fontWeight: 400
  cardTitle:
    fontFamily: "{typography.fontFamilies.subtitle}"
    fontSize: "1.4rem"
    fontWeight: 400
  subtitle:
    fontFamily: "{typography.fontFamilies.subtitle}"
    fontSize: "1.05rem"
    fontWeight: 400
  body:
    fontFamily: "{typography.fontFamilies.body}"
    fontSize: "1rem"
    fontWeight: 300
    lineHeight: 1.5
  prose:                                  # .article-content, long-form reading
    fontFamily: "{typography.fontFamilies.body}"
    fontSize: "1.2rem"                        # mobile prose base at 110% root
    fontSizeMd: "1.25rem"                     # desktop prose base
    sizeOffset: "-4pt … +4pt"                 # --prose-size-offset; 0 is this default
    lineHeight: 1.6
    dropCapLines: 2                       # --drop-cap-lines; _config.yml drop_cap_lines
    color: "{colors.*.onSurfaceVariant}"
    paragraphMargin: "1.15em"
  proseHeading2:                          # the display serif, with a rule above
    fontFamily: "{typography.fontFamilies.title}"
    fontSize: "1.7em"                     # 1.5em below 768px
    fontWeight: 400
    lineHeight: 1.2
    borderTop: "1px solid {borders.gentleDivider}"
  proseHeading3:                          # the label face, uppercase, primary
    fontFamily: "{typography.fontFamilies.label}"
    fontSize: "0.95em"
    fontWeight: 400
    letterSpacing: "0.1em"
    textTransform: "uppercase"
    color: "{colors.*.primary}"
  proseHeading4:
    fontFamily: "{typography.fontFamilies.body}"
    fontSize: "1em"
    fontWeight: 400
  marginalia:
    fontFamily: "{typography.fontFamilies.label}"
    fontSize: "0.75rem"
    fontWeight: 400
    letterSpacing: "0.05em"
  cardMeta:
    fontFamily: "{typography.fontFamilies.label}"
    fontSize: "0.8125rem"
    fontWeight: 400
    letterSpacing: "0.04em"
  cardTag:
    fontFamily: "{typography.fontFamilies.label}"
    fontSize: "0.75rem"
    fontWeight: 400
    letterSpacing: "0.03em"
  codeTechnical:                          # the fourth role — notation
    fontFamily: "{typography.fontFamilies.mono}"
    fontSize: "0.8125rem"
    lineHeight: 1.45
    fontVariantNumeric: "tabular-nums"
  codeTechnicalSm:
    fontFamily: "{typography.fontFamilies.mono}"
    fontSize: "0.75rem"
    lineHeight: 1.4
    fontVariantNumeric: "tabular-nums"
  code:                                   # inline code inside prose
    fontFamily: "{typography.fontFamilies.mono}"
    fontSize: "0.85em"

  # The apparatus inside an article descends from the prose in four steps, all
  # in onSurfaceVariant. Every one of them is a sentence, which is why none
  # takes the label or notation voice for its size.
  proseQuote:                             # blockquote, `>` in Markdown
    fontFamily: "{typography.fontFamilies.body}"
    fontSize: "0.95rem"                   # identical to proseNote by intent
    lineHeight: "{typography.body.lineHeight}"
    plate: "surfaceContainerLow, 2px tertiary left rule"
  proseNote:                              # .article-note, authored per article
    fontFamily: "{typography.fontFamilies.body}"
    fontSize: "0.95rem"
    lineHeight: "{typography.body.lineHeight}"
    plate: "surfaceCard, 3px tertiary bar"
  proseCaption:                           # figcaption, and the lightbox caption
    fontFamily: "{typography.fontFamilies.body}"
    fontSize: "0.9rem"
    lineHeight: 1.55
  proseBibliography:                      # .article-references .bibliography li
    fontFamily: "{typography.fontFamilies.mono}"
    fontSize: "0.85rem"
    lineHeight: 1.55

# ─────────────────────────────────────────────────────────────
# Shapes. Soft paper radius on cards; true pills stay circular.
# ─────────────────────────────────────────────────────────────
rounded:
  none: "0"
  card: "0"                               # --radius-card; square Borders Edition
  full: "9999px"                          # footer contact discs, timeline dot key
  tailwindScale:                          # remapped in assets/tailwind-play.js
    DEFAULT: "0.125rem"
    lg: "0.25rem"
    xl: "0.5rem"
    full: "0.75rem"                       # NOTE: not a pill

# The two canonical shard polygons, declared once in assets/css/base.css.
shards:
  alpha: "polygon(26% 0, 100% 0, 78% 100%, 0 68%)"     # --shard-alpha
  beta: "polygon(0 0, 74% 18%, 100% 100%, 18% 84%)"    # --shard-beta
  opacity: "12%"                          # --cubist-shard-opacity
  opacityStrong: "16%"                    # --cubist-shard-opacity-strong
  utility: ".shard-accent / .shard-accent-beta"
  suppressedBelow: "640px"

# ─────────────────────────────────────────────────────────────
# Spacing. A named scale in custom properties, in assets/css/base.css.
# Tailwind's default 0.25rem rungs are still in use in the Liquid chrome.
# ─────────────────────────────────────────────────────────────
spacing:
  scale:
    xs: "0.25rem"                         # --space-xs
    sm: "0.5rem"                          # --space-sm
    md: "1rem"                            # --space-md
    lg: "1.5rem"                          # --space-lg
    xl: "2rem"                            # --space-xl
    "2xl": "3rem"                         # --space-2xl
    "3xl": "4.5rem"                       # --space-3xl
  gutter: "2rem"                          # --gutter
  gutterMobile: "1rem"                    # --gutter-mobile
  tailwindRungsInUse: ["0", "0.5", "1", "1.5", "2", "2.5", "3", "3.5", "4", "5", "6", "8", "10", "12", "16"]

layoutTokens:
  shellMaxWidth: "80rem"                  # Tailwind max-w-7xl
  navPaddingX: ["1.5rem", "2rem", "2.5rem"]           # base / sm / md
  listingPaddingX: ["2rem", "4rem"]                   # base / md — px-8 md:px-16
  homeBandPaddingX: ["{spacing.gutterMobile}", "{spacing.gutter}"]  # base / md
  homeBandPaddingY: ["3rem", "4.5rem"]                # base / md — space-2xl / 3xl
  readingMeasure: "45rem"                 # --reading-measure; every page, prose and media alike
  legacyContainer: "64rem"
  breakpoints:
    sm: "640px"
    md: "768px"
    lg: "1024px"
    xl: "1280px"
  ownBreakpoints: ["639px", "767px", "900px"]         # max-width queries in ledger CSS

# ─────────────────────────────────────────────────────────────
# Components. The block library first — it renders most of the site.
# Source of truth: _includes/content-runtime/43-blocks.html for the markup,
# assets/css/base.css ("Architectural Ledger blocks") for the styling.
# ─────────────────────────────────────────────────────────────
components:
  langPill:                               # renderLangPill(language)
    typography: "{typography.fontFamilies.label} 0.725rem / 0.08em uppercase"
    padding: "0.1rem 0.4rem"
    border: "1px solid color-mix(in srgb, currentColor 35%, transparent)"
    color: "{colors.*.primary} for EN, {colors.*.secondary} for PT"
    backingField: "language"
  chip:                                   # renderTagChips(tags)
    typography: "{typography.fontFamilies.label} 0.725rem / 0.08em uppercase"
    padding: "0.15rem 0.45rem"
    backgroundColor: "{colors.*.surfaceHigh}"
    textColor: "{colors.*.onSurfaceVariant}"
    hoverBackgroundColor: "{colors.*.surfaceContainerHigh}"
    rounded: "{rounded.none}"
    backingField: "tags"
  metaStrip:                              # renderMetaStrip([parts])
    typography: "{typography.codeTechnical}"
    letterSpacing: "0.06em"
    textTransform: "uppercase"
    gap: "{spacing.scale.sm}"
    separator: "/ in outlineVariant, only between surviving parts"
  cta:                                    # renderCtaLink(href, label)
    typography: "{typography.fontFamilies.label} 0.8rem / 0.1em uppercase"
    textColor: "{colors.*.primary}"
    hoverTextColor: "{colors.*.linkHover}"
    icon: "→ (U+2192) text glyph, aria-hidden, translateX(4px) on hover"
  sectionBanner:                          # renderSectionBanner({kicker, title, note})
    kicker: "{typography.codeTechnical}, 0.12em, onSurfaceVariant"
    title: "{typography.sectionTitle}"
    note: "{typography.codeTechnical}, 0.08em, onSurfaceVariant"
    marginBottom: "{spacing.scale.xl}"
  ledgerRow:                              # renderLedgerRow(item)
    backgroundColor: "{colors.*.surfaceCard}"
    hoverBackgroundColor: "{colors.*.surfaceHigh}"
    padding: "{spacing.scale.lg}"
    rounded: "{rounded.none}"
    boxShadow: "none"
    titleHoverColor: "{colors.*.primary}"
  ledgerCard:                             # renderArchiveCard(item)
    backgroundColor: "{colors.*.surfaceCard}"
    hoverBackgroundColor: "{colors.*.surfaceHigh}"
    borderColor: "{borders.gentleSubtle}"
    borderWidth: "1px"
    padding: "{spacing.scale.lg}"
    rounded: "{rounded.none}"
    footBorderTop: "1px solid {borders.gentleDivider}"
  systemCard:                             # renderSystemCard(item)
    inherits: "{components.ledgerCard}"
    extras: "poster, label/status meta strip, repository + article + external links"
  poster:                                 # renderPosterMedia(src, alt)
    aspectRatio: "16 / 9"
    objectFit: "cover"
    backgroundColor: "{colors.*.surfaceContainer}"
    filter: "saturate(0.92) contrast(1.02)"
    hoverFilter: "saturate(1.05) contrast(1)"
    hoverTransform: "scale(1.02)"         # suppressed under prefers-reduced-motion
    videoBehaviour: "controls, preload=none — never autoplays"
  pageHeaderStandfirst:
    maxWidth: "{layoutTokens.readingMeasure}"
    fontSize: "1.05rem"
    lineHeight: 1.5                       # --leading-body
    backingField: "standfirst on the page header JSON"
  buttonSolid:                            # .home-cta--solid, .writing-lead-cta
    backgroundColor: "{colors.*.primary}"
    textColor: "{colors.*.onPrimary}"
    padding: "0.85rem {spacing.scale.lg}"
    rounded: "{rounded.none}"
  buttonOutline:                          # .home-cta--outline
    backgroundColor: "{colors.*.surfaceCard}"
    borderColor: "{borders.gentle}"
    textColor: "{colors.*.primary}"
    hoverBackgroundColor: "{colors.*.surfaceHigh}"
    hoverBorderColor: "{colors.*.primary}"
  filterChip:                             # .listing-filter-chip, shared controller
    backgroundColor: "{colors.*.background}"
    borderColor: "{borders.gentle}"
    padding: "0.35rem 0.65rem"
    rounded: "{rounded.none}"
    activeBorderColor: "{colors.*.secondary}"
    activeBackgroundColor: "color-mix(in srgb, {colors.*.secondary} 8%, {colors.*.background})"
  input:
    backgroundColor: "{colors.*.background}"
    borderColor: "{borders.gentleSubtle}"
    padding: "0.5rem 0.65rem"
    rounded: "{rounded.none}"
    focusOutline: "2px solid color-mix(in srgb, {colors.*.secondary} 45%, transparent)"
  popover:                                # .listing-filter-panel, nav menu
    backgroundColor: "{colors.*.surface}"
    borderColor: "{borders.gentle}"
    rounded: "{rounded.none}"
    boxShadow: "0 12px 32px color-mix(in srgb, {colors.*.onSurface} 12%, transparent)"

motion:
  stateChange: "0.15s ease"               # 23 declarations — the de facto standard
  legacyChrome: "0.2s ease"               # 8 declarations, pre-redesign chrome
  mediaFilter: "0.4s ease"
  mediaTransform: ["0.6s ease", "0.7s ease"]
  lightbox: ["160ms ease-out", "180ms ease-out"]
  readingProgress: "scroll(root block) timeline, beNewsreader @supports"
  reducedMotion: "5 rules — see Motion below"
---

# DESIGN.md — Brazilian Ledger

This file **describes the site as it is built today**, in both themes. It is a
record, not an aspiration: it says what the browser actually renders, not what
a mockup or an earlier document intended. Where the built site and a mockup
disagree, the built site wins and this file records the built site.

Source of truth for the values above:

| Concern | File |
| :--- | :--- |
| Palettes | [`_data/themes/light.yml`](_data/themes/light.yml), [`_data/themes/dark.yml`](_data/themes/dark.yml) |
| Shared type / motion | [`_data/themes/shared.yml`](_data/themes/shared.yml) — fonts and non-colour tokens used by both palettes |
| Token emission | [`_includes/theme/theme-vars-block.liquid`](_includes/theme/theme-vars-block.liquid) |
| Tailwind binding | [`_includes/theme/tailwind-theme-colors.json.liquid`](_includes/theme/tailwind-theme-colors.json.liquid), [`_includes/theme/tailwind-theme-fonts.json.liquid`](_includes/theme/tailwind-theme-fonts.json.liquid), [`assets/tailwind-play.js`](assets/tailwind-play.js) |
| Type, spacing, shards, shared components | [`assets/css/base.css`](assets/css/base.css) |
| **Block library (markup)** | [`_includes/content-runtime/43-blocks.html`](_includes/content-runtime/43-blocks.html) |
| Per-page styles | [`assets/css/ledger/`](assets/css/ledger/) — `home`, `writing`, `rascunhos`, `projects`, `sources`, `detail`, `cv` |
| Long-form prose (superseded in part) | [`assets/css/article.css`](assets/css/article.css) |
| Print | [`assets/css/cv-print.css`](assets/css/cv-print.css) |
| Shell chrome | [`_layouts/shell.html`](_layouts/shell.html) |

A note on names. The palette files still call the system the **Brazilian
Ledger**; the component layer the redesign added calls itself the
**Architectural Ledger**. They are the same design system. Nothing in the code
reconciles the two names.

---

## Overview

The site is a personal editorial archive: CV, long-form articles in English,
`rascunhos` (drafts) in Portuguese, projects, a bibliography of sources, and
an interactive network of ideas. The register is **structural rigour with
artistic soul** — a draughtsman's sheet rather than a SaaS landing page.

Four ideas carry it:

1. **Framed paper.** Cards and plates carry a thin, clear ink frame and stay
   square (`--radius-card: 0`). Depth still comes from the surface ladder
   and borders, not drop shadows. Drafting corner brackets and empty
   crosshairs are decoration only — never labels. Italic section-title
   halves and the hero family name take a marker highlight wash.
2. **Paper, not glass.** No drop shadows on content. Depth comes from the
   four-step surface ladder and from hairline / ink borders.
3. **A ledger voice for data.** Dates, spans, classifications, hosts, counts
   and reference numbers are set in monospace with tabular figures. This is
   the fourth type role, and it is what makes the site read as a register
   rather than a blog.
4. **Cubist shards, rationed.** Two canonical polygons, one utility class,
   five uses of it plus one hand-rolled pseudo-element. The motif is a
   signature now rather than a texture. The logo repeats it as three coloured
   facets.

**Theme switching.** `<html data-theme="light|dark">` is set before paint by
[`_includes/theme/shell-theme-boot.html`](_includes/theme/shell-theme-boot.html),
persisted under `localStorage["site-theme"]`, default `system`. Light is
additionally bound to `:root`, so it is the no-JS fallback. Both palettes emit
the *same token names*, so every component is theme-agnostic.

**How pages are built.** Listings and detail views are not Liquid. They render
in the browser from `_content_json` via JavaScript string templates in
[`_includes/content-runtime/`](_includes/content-runtime/), and the shared
block library is the bottom of that stack. Only the shell, the page headers,
the CV register frames, the timeline and the network graph are server-rendered.

---

## The block library

This is the most important thing to understand about the current build.
**Layouts no longer style their own cards.** Nine renderers in
[`_includes/content-runtime/43-blocks.html`](_includes/content-runtime/43-blocks.html)
produce every card, row, chip, pill, meta strip and CTA on the site; their CSS
lives in one block in [`assets/css/base.css`](assets/css/base.css) under
*Architectural Ledger blocks*. All nine are re-exported onto
`window.ContentRuntime` by `90-bootstrap.html`.

| Renderer | Renders | Root class | Backing field |
| :--- | :--- | :--- | :--- |
| `renderLangPill(language)` | a bordered `EN` or `PT` pill | `.lang-pill` | `language` |
| `renderTagChips(tags, {hrefFor, limit})` | row of filled chips, optionally links | `.ledger-chip-row` | `tags` |
| `renderMetaStrip([parts], {className})` | mono ledger line with `/` separators | `.ledger-meta.code-technical` | whatever the caller passes |
| `renderCtaLink(href, label)` | label + `→`, arrow slides on hover | `.ledger-cta` | `url` / an external link field |
| `renderSectionBanner({kicker, title, note})` | kicker over a section title, note right | `.ledger-section-banner` | static labels |
| `renderLedgerRow(item, opts)` | dense horizontal entry | `.ledger-row` | `title`, `date`, `language`, `tags`, preview — `opts.metaParts` replaces the date + pill strip |
| `renderArchiveCard(item, opts)` | vertical grid card | `.ledger-card` | `title`, `date`, `language`, `tags`, preview |
| `renderSystemCard(item, opts)` | project card with poster | `.ledger-system-card` | `project`, `thumbnail`, `label`, `status`, `tagline`, `tags`, `github`, `article_url`, `external_url` |
| `renderPosterMedia(src, alt)` | image, or video when the URL ends `.mp4`/`.webm`/`.mov` | `.ledger-poster` | `thumbnail` |

`blockFields(item)` is the shared reader underneath them. It takes
`front_matter.title | date | last_updated | language | tags`, falling back to
the item's own keys, and calls `listingPreview(item)` for the summary
(`description` → `excerpt` → an extract from `body_markdown`).

### The house rule

> **A block renders nothing when its field is absent.**

This is the project's central invariant and it is enforced at the renderer, not
at the call site. `renderLangPill` returns an empty string for an undeclared
language. `renderTagChips` returns an empty string for an empty array.
`renderMetaStrip` drops empty parts *and the separators that would have sat
beside them*, so a missing date never leaves a dangling slash.
`renderSectionBanner` returns nothing without a title. `renderCtaLink` returns
nothing without both an href and a label.

Nothing in the library derives a value, counts anything, or substitutes a
placeholder. There are no reading times, word counts, entry numbers, sequence
counters, status pills, version badges or fabricated metrics anywhere in the
build, and an absent field is never rendered as a dash, a placeholder string
or an "Unknown".

This matters because the corpus is uneven: of 67 exported entries, **29
declare a language**. The pill is therefore absent on more than half the site,
by design. A card with no tags is a card with no chip row, not a card with an
empty chip row.

Two listings go further and suppress the pill even where the field is set,
because every entry in them shares one language and the pill would only be
marking which entries declared the field: the rascunhos ledger
(`_layouts/blog.html`, all Portuguese) and the writing index
(`_layouts/articles.html`, all English). It still renders on the home page
bands, on the sources index — where French, English and Portuguese genuinely
mix — and on the article detail view.

`renderPosterMedia` extends the rule to runtime failure: a thumbnail that
404s removes its own `.ledger-poster` wrapper via an inline `onerror`, so a
dead third-party image leaves no empty plate beNewsreader.

### Where the library is not yet the only source

Recorded honestly, because the rule above is the design goal and these are the
gaps:

* **`_layouts/resources.html`** hand-builds the whole source card
  (`article.ledger-card.source-card`) rather than calling `renderArchiveCard`.
  It also forks `renderLangPill` into a local `languagePill()` to get a third
  `.lang-pill--other` variant for sources that are neither English nor
  Portuguese, and forks the pagination controls.
* **`_layouts/cv.html`** carries three local card shapes — `.cv-entry`,
  `.cv-language`, `.cv-product`. `renderProduct` in particular is structurally
  an archive card built from scratch.
* **`_layouts/blog.html`** builds its own thumbnail plate
  (`.rascunhos-row-media`) instead of calling `renderPosterMedia`, giving the
  site two poster implementations with different failure behaviour (an inline
  `onerror` attribute versus an attached `error` listener). It also re-parents
  the shared row's chip row into the head and deletes `.ledger-row-foot`.
* **`_layouts/home.html`** wraps shared leaves in a local `.home-featured`
  shape, and hand-writes its hero CTAs and four section banners in Liquid —
  class-for-class identical to `renderCtaLink` and `renderSectionBanner`, but
  duplicated, because those renderers are JavaScript.
* **`_layouts/articles.html`** wraps shared leaves in a local `.writing-lead`.
  Its rows now pass their strip in through `renderLedgerRow`'s `metaParts`
  (date, then a `span.writing-revised` when the entry has been rewritten)
  rather than grafting the revision onto `.ledger-meta` after construction.
* **`_layouts/text.html`** duplicates `renderTagChips` and `renderLangPill` in
  Liquid. This one is structural: `text.html` is the studio-only server-rendered
  path and cannot call the JavaScript renderers. Its markup is kept
  byte-compatible with theirs on purpose, so
  [`assets/css/ledger/detail.css`](assets/css/ledger/detail.css) styles both.

[`_layouts/projects.html`](_layouts/projects.html) is the clean case: one
`renderSystemCard` call and nothing else.

---

## Colours

### Brand triad

Three roles, configured per theme, used for **text, borders, rules, links,
solid call-to-action fills and cubist shards**. The redesign added the one
exception to the old rule that brand hues are never a fill: the primary
call-to-action (`.home-cta--solid`, `.writing-lead-cta`, the active filter tab
on the writing index) is a solid `primary` block with `onPrimary` text.

| Role | Light | Dark | Used for |
| :--- | :--- | :--- | :--- |
| Primary | `#255b75` ice slate | `#9dc2d6` | Links, family name, CTAs, active tab, `h3` in prose, reading-progress bar, register rules, text selection |
| Secondary | `#33774c` forest green | `#8fc29f` | Status labels, licence and marginalia chrome, footer, active filter chip |
| Tertiary | `#6e6c3d` ochre gold | `#d7d4a5` | Detail-page meta, print dates, the third card rule |

Contrast against each theme's canvas (re-measured after the 2026-09 vivid pass):

| Role | Light vs `#ffffff` | Dark vs `#0c0c0e` |
| :--- | :--- | :--- |
| Primary | 7.42 : 1 | 10.35 : 1 |
| Secondary | 5.41 : 1 | 9.66 : 1 |
| Tertiary | 5.42 : 1 | 12.89 : 1 |

All pass WCAG AA for body text on the canvas. `onPrimary` on `primary` stays
white-on-slate in light and dark-ink-on-light-slate in dark.

The 2026-09 vivid pass raises chroma on the existing Ledger hues rather than
adopting Stitch pigment hexes. In light the triad still separates mainly by
hue; in dark `tertiary` remains the brightest accent after body copy.

### The surface ladder

The redesign replaced the two-tone band alternation with a four-step ladder.
Both palettes emit the same three new tokens on top of `background`:

| Step | Token | Light | Dark | Used for |
| :--- | :--- | :--- | :--- | :--- |
| 1 — canvas | `--color-background` | `#ffffff` | `#0c0c0e` | page, default home band |
| 2 — panel | `--color-panel-contrast` | `#f4f4f4` | `#141418` | alternating bands, filter decks, CV dossier, writing lead, detail sidebar heading, marginalia panels |
| 3 — card | `--color-surface-card` | `#ffffff` | `#0c0c0e` | every `.ledger-row`, `.ledger-card`, `.ledger-system-card` at rest (solid background matching ambient layer; masks ambient background grid/patterns) |
| 4 — hover | `--color-surface-high` | `#ebebeb` | `#26262b` | row and card hover, chip fill |

Cards sit with solid surface color matching their parent plane (`#ffffff` canvas / `#f4f4f4` contrast band in light; `#0c0c0e` canvas / `#141418` contrast band in dark) so that ambient mesh and background grid patterns do not bleed through card content. Hover rungs lift via `--color-surface-high`.

### The older Material ramp

The eight-step Material surface ramp (`surfaceContainerLowest` through
`surfaceVariant`, plus `panelGrey`) is still emitted and still used — by the
nav, the footer, the filter popover, the prose `pre`/`code`/`blockquote` fills,
the timeline rails and the prev/next panels. It sits beside the ladder rather
than underneath it, and the two overlap: `surfaceCard` and
`surfaceContainerLow` differ by 1.037 : 1 in light and 1.014 : 1 in dark.
Two token families name nearly the same colour.

### Borders

Never a raw colour. Five opacity steps of `outlineVariant`, shared by both
themes: `gentleFaint` 22%, `gentleSubtle` 32%, `gentleDivider` 35%, `gentle`
62%, `gentleHover` 78%.

### Semantic and media colours

`error` / `errorContainer`, plus three resource-type accents that lighten in
dark (`resYoutube` `#c62828` → `#ef5350`, `resPodcast` `#2e7d32` → `#66bb6a`,
`resDoc` `#b45309` → `#ffb74d`). Note that the sources page does **not** use
them: `assets/css/ledger/sources.css` colours its medium labels and filter
swatches from the brand triad instead (`primary` for video, `secondary` for
audio, `tertiary` for documents, `outline` for websites), and every label
carries its own word so the hue never has to carry the reading alone.

The CV timeline carries the one genuinely categorical scale in the build, in
`_data/themes/*.yml` under `timeline:` and emitted as `--timeline-employment`
… `--timeline-post`. Six kinds of event are drawn at once and have to be told
apart, which three inks cannot do — before this existed, employment shared
`primary` with article and product shared `tertiary` with post. Hues are
spread roughly 18 / 42 / 140 / 168 / 200 / 245 and desaturated to stay in the
editorial register; dark lifts each in lightness rather than reusing the light
values.

It is held outside `colors:` on purpose. A `.page-accent--*` class rebinds
`--color-primary`, and the CV reads green — a chart drawn from the rebound
triad comes out one hue, which is a chart that cannot be read. **A chart's
palette is not the page's accent.** The lane tokens are also what the legend
swatches paint from, so the key cannot drift from the thing it explains.

### Terminal captures

The one palette on the site that does not follow the theme. An ` ```ansi `
fence in article prose renders a real terminal capture in colour, and the
sixteen base colours plus the ground are stated outright in
`assets/css/article.css` rather than drawn from the ladder:

| Property | Value | Note |
| :--- | :--- | :--- |
| `--ansi-bg` | `#12130f` | Fixed in both themes |
| `--ansi-fg` | `#d3d7cf` | Tango's white |
| `--ansi-fg-bold` | `#eeeeec` | Bold with no colour set |
| `--ansi-fg-dim` | `#9aa09a` | Resting copy control, 4.9 : 1 on the bar |
| `--ansi-0` … `--ansi-15` | Tango | Ubuntu's terminal palette |

Two reasons it is an exception rather than an oversight. ANSI colours are
defined against a dark terminal — bright yellow (`--ansi-11`, `#fce94f`) is
1.2 : 1 on the light palette's white canvas and simply disappears. And a
capture is a picture of something: it brings its own surface the way a
photograph brings its own light, and repainting it per theme would be
repainting the subject.

Tango specifically, because it is what Ubuntu's terminal ships, and the one
capture the site currently publishes — the `neofetch` block in the WSL
article — was drawn with it. Indices past 15 are the 6×6×6 cube and the
24-step grey ramp; those are arithmetic in the standard and are computed in
`_includes/content-runtime/25-code-blocks.html` rather than tabulated here.

Bold maps to the bright half of the palette in the renderer, not in CSS: it
is a terminal behaviour rather than a typographic one, and every tool that
paints a bold red means the bright one.

The type is `0.68rem / 1.15`, and both terms are set on the `pre` rather than
on the `code` inside it — `code` is inline, so the block establishes the line
boxes and a leading set on the `code` loses to the block's strut. 1.15 is a
terminal cell: VTE, which Ubuntu's terminal is built on, takes its row height
from the font's ascent plus descent and adds nothing, landing between 1.16 and
1.20 for the faces it ships. This is the one place on the site where prose
leading is actively wrong rather than merely loose — box drawing made of `s`,
`o` and `/` stops being a shape at anything near it.

---

## Typography

Owner stack (2026-10-01): **Cinzel Decorative** for *page / display* titles,
**Newsreader** for body and content titles (**Light 300** / **SemiBold 600**),
**Newsreader** for subtitle / standfirst roles that still use `--font-subtitle`,
**Marcellus SC** for labels / marginalia, **Courier Prime** for notation and
code. Declared once in `_data/themes/shared.yml` — light and dark only swap
colour. Root **110%**.
Titles are **+2pt** over the Stitch rem steps; chrome (meta, dek,
labels, nav, CTAs, mono) stays on the bare rem steps so dates, pills, and
“Read article” links do not outgrow the prose. Detail prose is **1.2rem** below 1024px (about **21.1px**) and
**1.25rem** from there (about **22px**). A reader can step that default
by −4…+4 pt (`--prose-size-offset`) from a compact dropdown.

Print CV keeps its own Lora / Overlock path in `cv-print.css` (untouched).

Type sizes live as `--type-*` tokens on `html` in `base.css`, mapped from the
Stitch Borders scale (§19.4 of reimagined-borders). Page CSS must consume
those tokens — no one-off rem sizes for roles that already have a step.

| Role | Family | Weight | Size token |
| :--- | :--- | :--- | :--- |
| Display | Cinzel Decorative | 400 | `--type-display` / `-lg` |
| Page H1 | Cinzel Decorative | 400 | `--type-page` / `-lg` |
| Section | Cinzel Decorative | 400 | `--type-section` / `-lg` |
| Detail title | Newsreader | 600 | `--type-title` / `-lg` |
| Card / row title | Newsreader | 600 | `--type-card` / `-lg` |
| Prose | Newsreader | 300 | `--type-prose` |
| UI body | Newsreader | 300 | `--type-body` |
| Detail standfirst | Newsreader | 300 | `--type-subtitle` (= body − 1pt) |
| Dek / masthead tags | Newsreader | 300 | `--type-dek` |
| Meta / dates / kickers | Newsreader | 300 | `--type-meta` |
| Chips / nav / SC | Marcellus SC | 400 | `--type-label` / `-lg` |
| Notation | Courier Prime | 400 | `--type-mono` |
| Code | Courier Prime | 400 | `--font-code` |

### Scale (Stitch-aligned)

| Token | rem | ~px at 110% root | Stitch analogue |
| :--- | :--- | :--- | :--- |
| `--type-display-lg` | 3.6515 | ~64 | display-hero |
| `--type-page-lg` | 2.9015 | ~51 | headline-lg |
| `--type-section-lg` | 2.1515 | ~38 | headline-md |
| `--type-title-lg` | 2.4015 | ~42 | detail H1 |
| `--type-card` | 1.4015 | ~25 | headline-sm |
| `--type-prose` | 1.2 | ~21.1 | reading body, under 1024px |
| `--type-prose` (≥1024px) | 1.25 | ~22 | reading body, desktop |
| `--type-body` | 1.0758 | ~19 | body-md |
| `--type-meta` | 0.8125 | ~14 | body-sm |
| `--type-label` | 0.8485 | ~15 | label-md |
| `--type-mono` | 0.8504 | ~15 | notation |

---

## Typography (implementation notes)

A page with `drop_cap: true` raises the first letter of the opening paragraph
across `--drop-cap-lines` (2 unless `_config.yml` says otherwise) in the
reading face, Newsreader, when the body does not open with a heading.

One leading token, `--leading-body: 1.5`, covers chrome and short body copy;
`--leading-prose: 1.6` covers long-form. Both are declared on `html` in
`base.css` and applied through `html body` rather than `body`, because
Tailwind's Preflight ships `body { line-height: inherit }` from the CDN
`<style>` that loads after this repo's sheets and wins a specificity tie on
source order.

Consumers spell `var(--type-*)`, `var(--leading-body)` or
`var(--leading-prose)` rather than repeat numbers. Code blocks, figure
captions, verse and chart labels may keep local leading; they are not body
copy.

### The notation role



`.code-technical` (0.85rem / 1.5) and `.code-technical-sm` (0.75rem / 1.4) both
set `font-variant-numeric: tabular-nums`. This is the role that carries the
ledger reading: `renderMetaStrip` applies `.code-technical` unconditionally, so
every meta line on every card is mono, and the CV, the rascunhos ledger head,
the sources host line, the network hint and the detail back link all follow.
`.code-technical-sm` is defined but nothing uses it.

### Display scale

| Token | Base | Larger | Line height |
| :--- | :--- | :--- | :--- |
| `pageTitle` | 3.625rem | 5.875rem (≥768px) | 0.95 |
| `homeHeroTitle` | `clamp(var(--type-section), calc(100cqi * 0.92 / 14.5), var(--type-page-lg))` | floor `--type-section-lg` (≥640px) | 1.05 |
| `pageHeaderTitle` | 2.5rem | 3.5rem (≥768px) | 1.15 → 1.1 |
| `textTitle` | 2.15rem | 2.65rem (≥768px) | 1.12 |
| `textTitle` in the dossier | 1.95rem | 2.25rem (≥1024px) | 1.15 |
| `sectionTitle` | 2rem | 2.375rem (≥640px) | 1.1 |
| `cardTitle` | 1.625rem | — | 1.2 |

The home hero sizes to its copy column through a container query on
`.home-hero-copy`. The preferred term is `100cqi * 0.92 / 14.5`, capped at
`--type-page-lg`. The floor is the band-title step (`--type-section`, then
`--type-section-lg` from 640px) so the name meets Articles, Rascunhos, and
Projects on a phone instead of falling to the card size. Below 768px the
name may wrap (`white-space: normal`); from 768px it stays one line. The
given name is `onSurface` and the family name is `primary` on the same
line. An earlier container-query fit —
`min(4.875rem, calc(100cqw * 0.96 / 4.5))`, whose `4.5` was the advance of
`"Hello, I am"` in Lora — remains in `base.css` but reaches no markup.

### Prose

`.article-content` runs at `1.1rem / var(--leading-body)` inside a `45rem`
measure, paragraph margin `1.15em`. At 1280px and above that measure holds
about 81 characters to the line, which is long for the leading; the measure is
a known open question rather than a tuned value.

Its ink is `onSurface` — pure black in light, pure white in dark — so body
copy and titles share the full foreground. Meta, captions, chips and other
chrome stay on `onSurfaceVariant`.

* **`h2`** is the display serif at `1.6em / 400`, with a `gentleDivider` rule
  above and `--space-2xl` of air, so a long article reads as a sequence of
  plates. It drops to `1.4em` below 768px, and the first `h2` in the column
  loses its rule.
* **`h3`** is the label face at `0.95em`, uppercase, `0.1em` tracking, in
  `primary`.
* **`h4`** is the body sans at `1em / 600`.
* **`h1`** is untouched from the old build: body sans, 600, `1.4em`. It is
  rare in prose and has no rule above it.

`pre` takes a 2px `outlineVariant` left rule on `surfaceContainer`;
`blockquote`, `.article-note`, tables with zebra `nth-child(even)` rows, MathJax
display blocks, Mermaid diagrams and the superscript citation apparatus are all
styled in [`assets/css/ledger/detail.css`](assets/css/ledger/detail.css), which
loads after and overrides much of `article.css`.

**Media sits at the measure, everywhere.** Every figure, video, Plotly embed
and Mermaid diagram is capped by `--reading-measure`, the same as the prose
around it, and a diagram wider than that scrolls inside its own plate rather
than pushing past the column. The projects page used to be the exception: it
released its whole body from the measure and handed the measure back to a
whitelist of text blocks, so a plate ran 18% wider than its paragraph at
1440px and 6% wider at 1280px. Neither width read as a deliberate break out of
the column, and the same includes sat differently there than on an article.

**Every piece of media sits on a plate.** `.article-content figure` gives all
of them one ground in both themes, so a light Matplotlib export and a dark
simulation video do not arrive as two surfaces. That means the `figure`
element is the contract: an include that emits a bare `<div>` or a bare
`<img>` silently opts out of it, which is how YouTube embeds and cut-in
portraits went unplated for as long as they did.

**The apparatus scale.** Below the prose's `1.1rem` the article descends in
four steps, all set in the body ink: a quote and a note share `0.95rem`, a
caption takes `0.9rem`, a bibliography entry `0.85rem`. A quote and a note are
deliberately indistinguishable as type, since both are a passage set aside from
the argument; only the plate tells them apart. Captions are the one step that
moves in two files, because `article.css` scopes `.article-content figure
figcaption` at `(0,1,2)` and outranks `detail.css`'s `(0,1,1)` — change one
without the other and figures keep the old size while a bare caption moves.

The bibliography is the last thing in an article still set in the notation face
while being made of sentences, which the notation rule above says it should not
be. Left as-is for now; its size no longer compounds the problem.

**Code blocks.** A fenced block is wrapped in a `.code-block` container by
`_includes/content-runtime/25-code-blocks.html`, which gives it the chrome an
editor gives a file: a `surfaceContainerHigh` bar over a `surfaceContainer`
pane, the language on a tab drawn in the pane's own fill with a 2px `primary`
inset rule across its top edge, and a copy control at the right in the label
register. Square and hairline-bordered like the ledger cards. The container
carries the fill and the frame, so the `pre` inside is zeroed back to a scroll
box — that override is three classes deep and so beats the `detail.css` rule
above without depending on sheet order. A ` ```mermaid ` fence is skipped; an
` ```ansi ` fence takes the terminal palette instead (see
[Terminal captures](#terminal-captures)).

### Label register

Uppercase label and notation text is the site's connective tissue.
Letter-spacing in use, by frequency: `0.1em` (12), `0.08em` (10), `0.12em` (7),
`0.04em` (4), `0.14em` (3), `0.05em` (3), `0.2em` (2), `0.06em` (2), `0.02em`
(2), `0.25em` (1), `0.16em` (1), plus `-0.01em` (3) as a display pull.

---

## Layout

* **Shell.** `max-width: 80rem` centred. The nav pads `1.5rem` → `2rem` (sm) →
  `2.5rem` (md); listing and detail mains pad `2rem` → `4rem` (md); home bands
  pad `--gutter-mobile` → `--gutter` (md).
* **Nav.** Sticky, `bg-surface`, logo + `|` divider + theme toggle on the left,
  a single **Explore** hamburger on the right *at every breakpoint* — there is
  still no persistent horizontal nav, and no responsive visibility class
  anywhere in the bar. The menu is a bordered popover grouped from `_data/nav`.
  A `1px` tonal strip closes the bar.
* **Home.** Six full-bleed `.home-band` sections, `--space-2xl` → `--space-3xl`
  (md) of vertical padding, each closed by a `gentleDivider` rule, alternating
  `background` and `.home-band--contrast` (`panelContrast`): hero, featured,
  writing, rascunhos, systems, ideas graph. The featured band carries a 6rem ×
  3px `primary` rule at its top-left corner as a structural mark. The three
  writing cards take `primary` / `secondary` / `tertiary` 2px top rules in
  rotation. The systems band is a specimen bench. The specimen is a
  fixed-height system card (2px `primary` top rule; strip with folio, label,
  start year and status; a 16:9 plate, the poster with an icon badge or the
  icon plate, the name's initial standing in for a missing icon; the title
  always below the plate; a tagline clamped to the
  height the plate leaves; tags, outbound links and an emphasis "Open
  project" cue). From 900px it takes 50% of the band, beside a 34%
  `panelContrast` filing rack of equal-flex project cards (16:9 thumb, code
  line, title, tagline; the selected card steps to `surfaceHigh` with a 3px
  `primary` inset rule), the rest left blank. Rack click swaps the specimen
  in place; specimen click opens the project. Below 900px the rack is an
  icon strip above the specimen, one equal column per project (up to six)
  so it spans the band. Contract: `PLT-AC-13`–`17` in
  `templates/portfolio/README.md`. Below 768px the hero portrait runs to the screen edge, pulled
  out of the band's gutter by exactly `--gutter-mobile` on each side and losing
  its side hairlines, which at the edge would read as a frame cut off.
* **Writing index.** Masthead over a hairline, then a `panelContrast` filter
  deck (tag tabs, sort, keyword), then a `panelContrast` lead panel for the
  newest entry, then an archive of `.ledger-row`s under a section banner.
* **Rascunhos.** Masthead with a shard, the shared filter panel unfolded into a
  full-width strip, then a two-column body: a 3/1 split at 1024px of ledger
  rows beside a sticky marginalia column. Rows become two-column
  (`.rascunhos-row--illustrated`, a 7.5rem plate, 4rem on phones) only when an
  image is actually present.
* **Projects.** A session-featured lead plate (with a Featured chip) over a
  `grid-cols-1 md:grid-cols-2` of system cards with `align-items: start`, so a
  card without a poster does not stretch to match one that has one.
* **Sources.** `.listing-card-grid--sources`: one column, two from 768px,
  three from 1024px, posters at `16 / 9` — the video frame, which is what most
  of the collection links to. Filtering hides pre-rendered cards with a class
  rather than re-rendering them.
* **Detail pages.** Two columns from `768px` — a 3/9 split of a left `aside`
  carrying a `panelContrast` dossier (title, description or thumbnail, tags,
  language, dates) and the prose column at `45rem` on the right. The sticky
  table of contents appears in that sidebar only from `1024px`; below it, the
  same list is mounted as a `<details>` disclosure instead. A 2px `primary`
  reading-progress bar is drawn on a pseudo-element of the detail section with
  `animation-timeline: scroll(root block)`, beNewsreader an `@supports` guard, so
  engines without scroll-driven animation simply get no bar.
* **CV.** A `panelContrast` dossier band with two shards, then five
  `.cv-register` sections and a timeline band. Each register is a 3/9 grid at
  1024px with the section title in a sticky left rail under a 2.5rem `primary`
  rule, and the entries running past on the right.
* **Breakpoints.** Tailwind's `640 / 768 / 1024 / 1280` for `min-width`; the
  ledger sheets add `max-width` queries at `639px` (shard suppression, phone
  row metrics), `767px` (prose `h2`, sidebar padding, filter facet stacking) and
  `900px` (the writing deck's own column collapse).

---

## Elevation & depth

The model is **tonal layering plus hairlines, never shadow**.

* **Content shadows: none.** Exactly two non-`none` `box-shadow` declarations
  exist in the whole build: the listing filter popover (`0 12px 32px` of
  `onSurface` at 12%, dropped below 768px where the panel goes inline) and a
  1px ring on the timeline's hovered bar. The nav menu adds Tailwind
  `shadow-sm`. The print sheet blanket-zeroes `box-shadow` on every descendant.
* **Hairline borders do the real work.** Because no rung of the ladder clears
  1.16 : 1, boundaries are carried by `1px solid` borders at one of the five
  `gentle*` opacities. There are 63 such declarations in the hand-written
  stylesheets — 13 in `base.css`, 9 in `article.css`, 37 across `ledger/`, 4 in
  `cv-print.css`.
* **Hover never lifts.** It steps the surface (`surfaceCard` → `surfaceHigh`),
  shifts the title to `primary`, shifts a border toward `gentleHover` or
  `primary`, or warms and scales a poster.
* **The print sheet has no surfaces at all.** Paper gets rules, not bands: a
  full-strength hairline for a section, a half-strength one for an entry.

---

## Motion

**Five tokens, and nothing outside them.** The scale is emitted by
`_includes/theme/theme-vars-block.liquid` onto `:root` and every `[data-theme]`,
so it survives a palette flip like any other custom property:

```css
--motion-duration-fast: 0.15s;   /* state change: colour, border, background */
--motion-duration-base: 0.4s;    /* poster filter warm-up */
--motion-duration-slow: 0.7s;    /* poster and plate scale */
--motion-ease-default: ease;
--motion-ease-out: ease-out;
```

Every `transition` and `animation` in the hand-written CSS reads them — 40
declarations, 60 duration references, 53 of them `fast` — including the two
inline `<style>` blocks in `_includes/page/`. Adopting the scale collapsed the
near-duplicates the convention had accumulated: the old `0.2s`, `180ms` and
`150ms` state changes are all `fast` now, the `0.6s` poster scales are `slow`,
and the lightbox's `160ms`/`180ms ease-out` keyframes are `fast` plus
`--motion-ease-out`, which is the token's only use.

Two literals survive on purpose, neither of them motion: the `99999s ... 0s`
WebKit autofill suppression on the filter input (`base.css`), and the `1ms
linear` on the reading-progress bar, where the duration is a placeholder that
`animation-timeline: scroll(root block)` overrides.

**Scroll-driven animation** is new: the reading-progress bar in
`ledger/detail.css` uses `animation-timeline: scroll(root block)` beNewsreader an
`@supports` guard, with a 1ms `linear` animation scaling a fixed 2px `primary`
bar from 0 to 1.

**`prefers-reduced-motion: reduce` is honoured globally.** One query in
`_includes/theme/theme-vars.html` zeroes the three duration tokens, so every
transition and animation that reads one stops dead. Nothing has to opt in, and
a new rule cannot forget to.

Six local blocks remain, because a zero duration removes the *tween*, not the
end state — a `transform` still lands, it just lands instantly:

| File | What it disables |
| :--- | :--- |
| `base.css` | the system card poster's `scale(1.02)` |
| `ledger/home.css` | the hero plate image's `scale(1.02)` |
| `ledger/writing.css` | the writing lead poster's `scale` |
| `ledger/rascunhos.css` | the thumbnail filter transition |
| `ledger/detail.css` | the reading-progress bar, which is scroll-driven and so outside the token scale |
| `article.css` | the lightbox keyframes, belt-and-braces since they now read `fast` |

Colour and background fades are no longer an exception: they read `fast` like
everything else, so the query catches them too.

---

## Shapes

* **`--radius-card: 0` keeps cards square.** Ledger cards, system cards,
  chips, emphasis CTAs, the home hero plate and index panels stay hard
  rectangles. Drafting corner brackets (`.ledger-frame-corners`) and empty
  crosshairs (`.ledger-frame-crosshairs`) are pure decoration with no text.
  Marker washes (`.ledger-marker`, `.section-title em`) highlight field-backed
  words only. `ledger/detail.css` still zeroes radius on prose `code`,
  `pre`, `blockquote` and `.article-note` where needed for reading;
  `cv-print.css` zeroes radius on every descendant for print.
* **True pills stay circular.** Footer contact discs and the timeline legend
  mark use `9999px`. `404.html`'s `rounded-xl` buttons resolve through
  `assets/tailwind-play.js`'s remapped radius scale.
* **Cubist shards** are now a primitive. Two polygons are declared once in
  `base.css`:

  ```css
  --shard-alpha: polygon(26% 0, 100% 0, 78% 100%, 0 68%);
  --shard-beta:  polygon(0 0, 74% 18%, 100% 100%, 18% 84%);
  ```

  `.shard-accent` is an absolutely positioned, `pointer-events: none`,
  `z-index: 0` element clipped by `--shard-alpha` at
  `--cubist-shard-opacity: 12%`; `.shard-accent-beta` swaps in the other
  polygon. A single `@media (max-width: 639px)` rule hides every one of them.
  Placement, size and hue are set per use by the page stylesheet, never by the
  utility.

  Fifteen uses site-wide, all `aria-hidden`. No panel carries two shards in
  the same corner or the same hue, and no two panels carry the same pair of
  corners, which is the whole rule the placement follows:

  | Where | Class | Corner | Hue |
  | :--- | :--- | :--- | :--- |
  | Home hero band | `.home-hero-pandorga` (geometric kite & ribbon) | background | `primary` / `secondary` / `tertiary` |
  | Home hero portrait | `.shard-accent.home-hero-shard` | top-right | `primary` |
  | Home featured card | `.shard-accent.home-featured-shard` | top-left | `tertiary` |
  | Home featured card | `.shard-accent-beta.home-featured-shard--beta` | bottom-right | `secondary` |
  | Home index panel | `.shard-accent.home-index-shard` | bottom-right | `secondary` |
  | Home index panel | `.shard-accent-beta.home-index-shard--beta` | bottom-left | `primary` |
  | Writing index lead panel | `.shard-accent.writing-lead-shard` | bottom-left | `primary` |
  | Writing index lead panel | `.shard-accent-beta.writing-lead-shard--beta` | top-right | `tertiary` |
  | CV dossier | `.shard-accent.cv-dossier-shard` | top-right | `secondary` |
  | CV dossier | `.shard-accent-beta.cv-dossier-shard--beta` | bottom-left | `primary` |
  | Projects lead | `.shard-accent.projects-lead-shard` | top-right | `primary` |
  | Projects hero | `.shard-accent.projects-hero-shard` | bottom-right | `secondary` |
  | Rascunhos masthead | `.shard-accent.rascunhos-shard` | top-right | `secondary` |
  | Sources masthead | `.shard-accent.sources-masthead-shard` | top-right | `secondary` |
  | Sources foot | `.shard-accent-beta.sources-foot-shard` | bottom-left | `tertiary` |
  | Site footer | `.shard-accent.site-footer-shard` | bottom-right | `secondary` |
  | Site footer | `.shard-accent-beta.site-footer-shard--beta` | bottom-left | `primary` |

  Two placement traps this build has already fallen into. A `--beta` element
  carries both class names, so any media query that repositions the pair has to
  restate the base rule's `auto` offsets on the beta: leave all four set and
  the browser resolves to top and left, and the pair collapses into one corner.
  And a shard beNewsreader an opaque plate is a shard nobody sees, which is why the
  home featured pair goes around its poster rather than across the card.

  On the writing index the shard was for a long time written to stand down
  whenever the featured entry carried a thumbnail — and that panel selects the
  first entry that *has* one, so the condition was always true and the shard
  never rendered on a built page.

  A further shard sits on the detail sidebar heading. It is a `::after`
  pseudo-element, so it cannot take the utility class and re-implements it by
  hand — including its own 639px suppression.
* **Icons** are Material Symbols Outlined, `FILL 0, wght 400, GRAD 0, opsz 24`,
  sized explicitly per context (`1rem` in the back link, `1.05rem` on the deck
  search, `1.1rem` on a system card, `1.25rem` in chrome).
* **Card media** is a `16 / 9` `object-fit: cover` crop — `4 / 3` on rascunhos
  rows — never letterboxed. The home page is the exception: both its plates are
  measured against the copy beside them rather than against a ratio. The
  featured plate takes `--home-featured-plate-height` (its title's line plus
  four lines of description), and the draft rows' plates `align-self: stretch`
  so they square off against the chip row that closes the entry.

---

## Page chrome

### Bands and plates

`.home-band` is the universal full-bleed container: no border except the
`gentleDivider` rule that closes it, no shadow, `panelContrast` when it carries
`.home-band--contrast`. Four panel-step plates carry a shard —
`.writing-lead`, `.rascunhos-panel`, `.cv-dossier` and
`.text-detail-sidebar .article-sidebar-heading` — so each takes
`overflow: hidden` and lifts its content clear with `position: relative;
z-index: 1`. The filter decks and `.rascunhos-pagination` are plain
`panelContrast` strips. `.home-hero-plate` and `.home-graph-plate` sit a rung
lower, on `surfaceCard`, beNewsreader a `gentleSubtle` hairline.

### Filter deck

Two shapes over one controller (`_includes/content-runtime/42-listing-filter.html`).
The writing index renders it inline as a `panelContrast` strip of tag **tabs**
— solid `surfaceCard` fills, the active one inverting to a solid `primary`
block — plus a sort group and a mono keyword field. Rascunhos takes the shared
`page-header.html` popover and unfolds it into a full-width strip, removing the
trigger button so it cannot re-collapse. Sources and the network graph keep the
popover as a popover. The classification axis changed from `category` to `tag`
in the controller; resources still filter on `category`.

### CV

`.cv-register` sections separated by a `gentleDivider` top rule and
`--space-3xl`. Entries are hairline-separated rows, not boxes: a mono role
line, a display institution line, a mono place line, body copy, and an optional
chip row of related products. Languages are a name, a dotted leader and a mono
level.

### Print CV

[`assets/css/cv-print.css`](assets/css/cv-print.css) now runs the same four
type roles on paper: Simonetta for the name and entry titles, Newsreader for
prose, small-caps section labels and organisations, mono for
dates, URLs, email and phone. The header carries a mono kicker above the name —
the paper counterpart of the dossier strip. Sections are a small-caps label
with a hairline running out to the margin; jobs are separated by half-strength
rules rather than wrapped in cards, because the mockup's card shape would have
put eight grey blocks on an A4 sheet. The layout pins `data-theme="light"`, so
only the light palette is ever in play, and a local reset zeroes radius and
shadow on every descendant because the sheet ships no utility framework.

### Footer

`surfaceContainerLow` with a `gentleDivider` top border, `3rem` vertical
padding, marginalia in `secondary`, contacts injected at runtime as circular
discs.

---

## The field contract

An element renders only if a populated field backs it. The classification axes,
as enforced by [`_plugins/lib/tag_validator.rb`](_plugins/lib/tag_validator.rb):

* **Articles** classify on `tags`, one to three, from a closed English
  vocabulary: `Aesthetics`, `AI`, `Data`, `DevOps`, `Mathematics`,
  `Robotics`, `Social`. All 22 carry them.
* **Rascunhos** classify on `tags` too, by subject and in Portuguese, **zero to
  three**: `arte`, `brasilidade`, `carme`, `devaneio`, `engraçadinho`,
  `música`, `pesquisa`, `provocação`, `técnico`, `trabalho`. Unlike articles
  the field may be empty — a notebook holds pages that file nowhere. 29 of 30
  carry at least one.
* `category` is rejected on both collections — one classification axis, not
  two.
* **Projects** carry free `tags` (all 8 do), plus `label`, `status`,
  `start_date`, `end_date`, `icon`, `thumbnail`, `github`, `article_url`,
  `external_url`.
* **Resources** are the exception that keeps `category` (`Academic`,
  `Communication`, `Humor`, `Music`, `Professional`) alongside a `type` of
  `youtube` / `podcast` / `website`.
* **`language`** (`enus` / `ptbr`) is optional and exported into both
  `writing_index.json` and the per-object JSON. 29 of 67 entries declare one.

`writing_index.json` carries 29 keys per entry; detail views read the full
`front_matter` plus `body_markdown` from
`_content_json/collections/<coll>/<slug>.json`.

---

## Do's and Don'ts

### Do

* **Do reach for a block before writing a card.** If a layout needs a card,
  row, chip, pill, meta strip or CTA, call the renderer in `43-blocks.html`.
  Another local card shape is the failure mode this library exists to stop.
* **Do let an absent field render nothing.** No placeholder, no dash, no
  derived stand-in, no counter.
* **Do keep every corner at `0`.**
* **Do take depth from the ladder**, and pair it with a hairline — no rung
  clears 1.16 : 1 on its own.
* **Do set notation in `.code-technical`** — dates, spans, hosts, counts,
  reference numbers, kickers.
* **Do keep long-form prose at `var(--reading-measure)`.**
* **Do reach for `--space-*` and `--gutter`** in any new CSS rather than a
  literal length.
* **Do use `--shard-alpha` / `--shard-beta`.** Do not draw a new polygon.
* **Do emit identical token names in both palettes** so components never branch
  on theme.
* **Do set `font-synthesis: none` on title text.** Simonetta ships 400 and 900 and nothing between; the gap must not be faked.
* **Do reuse `.ledger-cta` / `.ledger-cta--emphasis` / `.ledger-cta--emphasis-alt`
  (`base.css`) for any CTA that used to reach for a padded, solid-filled
  button.** `--emphasis` is the primary hue tinted fill; `--emphasis-alt` swaps
  to the secondary hue for a second button-level action beside it (e.g. the
  home hero's "Full curriculum vitæ" / "Contacts" pair). Don't add another one-off
  button class — the old `.home-cta` / `--solid` / `--outline` family was
  retired in 2026-09 specifically because every page had started growing its
  own.
* **Do scope a page's accent with `.page-accent--<color>` on its top-level
  container.** The two classes live in `base.css` (`--green` for Articles and
  the CV, `--ochre` for Rascunhos and Network of Ideas; Projects and Sources
  need none, blue is the default primary). Each rebinds `--color-primary` /
  `--color-link` / `--color-link-hover` to an existing triad token — never a
  new hex — and everything under it that reads those variables (card titles,
  CTAs, section-title `<em>` accents, filter chips) follows automatically
  through CSS inheritance. Categorical drawings that must keep the absolute
  slate / forest / ochre map (network graph nodes, type-keyed ambient pools)
  read `--triad-primary` / `--triad-secondary` / `--triad-tertiary` instead —
  those aliases are frozen in the theme vars block and are not rebound. Add a
  variant in `base.css`, not in a `ledger/*.css`: the green one was duplicated
  across two page stylesheets within a week of being written.
* **Do let tag chips carry the page accent.** `.ledger-chip` mixes
  `--color-primary` into both its fill (10%) and its ink (78%), so a chip is
  blue on Projects and Sources, green on Articles and the CV, ochre on
  Rascunhos and Network, with no per-page rule. Hover steps the fill to 22%
  and adds a 35% accent hairline as an inset ring rather than a border — a
  border would have to exist at rest to avoid a 2px jump, and its padding
  compensation only nets to zero at integer device pixel ratios. The
  page-header tag line (`data-content-header-tags`, e.g. the CV's
  "Engineering Leadership. Team Building…") is deliberately not a chip and
  stays neutral.
* **Do introduce a home band with a kicker, a title and a note**, all three
  from `content/pages/headers.yml` so the owner can edit them in Studio. The
  title is the same field the band's listing page reads for its own header.
  A band that opens straight onto cards gives the reader no way in. Each of
  the three renders nothing when its field is empty.
* **Do mix a hover tone toward `--color-on-surface`, not toward a
  `*-fixed-dim` token.** Those tokens carry the same value in both palettes,
  so they lighten a link on hover in *both* — right against a near-black
  canvas, wrong against white paper, where emphasis has to go darker. The
  foreground ink is dark in light and light in dark, so mixing toward it
  moves the correct direction in each theme on its own.
* **Do give a project-card link an icon that names its destination**
  (`renderCtaLink`'s `icon` option in `43-blocks.html`: `code` for a
  repository, `article` for a write-up, `public` for an external site, the
  entry's own `fm.icon` for "Details"). A destination icon is a *leading*
  marker and renders before the label, in `.ledger-cta-icon`, with no hover
  slide. Every other CTA keeps the trailing directional glyph — since 2026-09
  a Material `chevron_right` rather than a `→` — in `.ledger-cta-arrow`,
  which does slide on hover.

### Don't

* **Don't write a hex.** Everything resolves through `_data/themes/*.yml` → CSS
  custom properties → Tailwind token names. A literal is correct in one palette
  and wrong in the other.
* **Don't fill a panel, card or row with a brand hue.** A CTA earns a tinted
  fill (`.ledger-cta--emphasis`, `~14%` of the accent colour, brightening to a
  full fill on hover) for the one or two truly primary actions per page — that
  is the sanctioned exception, not a flat opaque brand-colour block.
* **Don't add drop shadows to content.** Shadows are for floating overlays.
  Depth on a card or panel is the ladder rung plus its hairline, and on hover
  the rung plus a hairline warmed toward the page accent (`.ledger-card:hover`
  mixes `--color-primary` at 40% into the border — the reference mockup's
  "hairline transitions to warm antique brass at 40%", made accent-aware).
  One sanctioned exception, added 2026-09: a wide, very low opacity accent
  pool sits *beNewsreader* a band. It is a backdrop, not a content effect — no card,
  panel or row gains a glow, and the pool is blurred past any visible edge so
  it reads as ambient light in the room rather than as a shape. Three of them
  ship: the home hero at 7% (`.home-band--hero::before`), the home Sources and
  Network band at 5% (`.home-band--index::before`), and one beNewsreader the Network
  of Ideas graph at 7%, whose centre and width are read off the settled D3
  layout rather than fixed (`assets/css/ledger/network.css`).

  **All three are dark-palette only**, gated on `[data-theme="dark"]`. The
  hero pool used to be unconditional, on the written assumption that it
  disappeared against a white light-theme canvas; the canvas has been warm
  paper since the ladder was inverted, and `--color-primary` inverts polarity
  between the palettes, so on light the rule painted a dark accent over paper.
  Near-equal RGB distance (20.3 dark, 19.3 light) resolves to 0.53 points of
  luminance on the near-black canvas and 9.11 on paper — about seventeen times
  the shift, in the palette the effect was never designed for. There is no
  light variant: paper has no headroom to lighten into.
* **Don't tint a page background off-brand.** Dark is a neutral-to-blue
  near-black (`#0c0c0e` canvas) — not olive or green. Light *is* warm paper
  (`#f4f2ed`), and that is deliberate: it is where the *gauchismo* half of
  the identity actually lives. This rule used to read "light is pure
  `#ffffff`, never cream" — that was written when cards were grey on white,
  and it was reversed in 2026-09 along with the ladder. Cream as a *canvas*
  is correct; cream as a random panel tint still is not.
* **Do step a card toward the light, in both themes.** Dark: canvas `#0c0c0e`
  → card `#1a1a1e`. Light: canvas `#f4f2ed` → card `#fffdf9`. A card that
  steps away from the light reads as recessed and, on white, as disabled —
  which is what the light theme did until 2026-09.
* **Don't introduce a fourth webfont.** Four roles, three families plus the
  system mono stack.
* **Don't autoplay a poster.** Project captures run to several megabytes;
  `renderPosterMedia` ships `preload="none"` and `controls`.
* **Don't invent content furniture** — no reading times, word counts, entry
  numbers, sequence counters, invented status pills, fabricated metrics,
  benchmarks, commit hashes or version badges.
* **Don't edit `43-blocks.html` for one page's needs.** A block that only one
  layout wants belongs in that layout's `ledger/*.css` and markup.

---

## Known inconsistencies in the current build

Recorded so the next pass resolves them deliberately rather than re-copying
them.

1. **Two names for one system.** `_data/themes/*.yml` says "Brazilian Ledger";
   `base.css`, `cv-print.css` and every `ledger/*.css` header say
   "Architectural Ledger". Nothing reconciles them.
2. **The block library is not yet the only source of cards.** Five layouts
   still hand-build card or row markup — see *Where the library is not yet the
   only source*. The sources card and the CV's `renderProduct` are archive
   cards rebuilt from scratch; rascunhos is a second poster implementation with
   different failure behaviour; `renderLangPill` is forked twice (sources'
   `lang-pill--other`, `text.html`'s Liquid copy).
3. ~~**The ladder's rungs are smaller than the step they replaced.**~~
   **Addressed 2026-09.** The dark canvas dropped to `#0c0c0e` and the rungs
   were respread to roughly +4.3 / +3.1 / +6.0 L\*, which is the mockup's own
   spacing; light was deepened more modestly, since white paper has less room
   to give and its warm cast is deliberate. Note that contrast *ratio* is the
   wrong instrument down here — the +0.05 flare term in the WCAG formula
   flattens every near-black pair to ≈1.05 : 1 no matter how far apart they
   look — so the rungs are specified in L\* instead.
4. **Two surface families name the same colours.** `surfaceCard` vs
   `surfaceContainerLow` and `surfaceHigh` vs `surfaceContainerHigh` still
   name near-identical values. The consequence this entry used to cite —
   `.ledger-chip`'s hover being invisible, since it stepped from one family
   to the other — was fixed in 2026-09 by giving the chip an accent-tinted
   fill and hairline of its own instead of a ladder rung (it was a literal
   no-op in dark: the two values were identical). Collapsing the two families
   into one is still the real fix and is still open.
5. **Two spacing systems.** `--space-*` governs the hand CSS; 176 Tailwind
   rungs govern the Liquid chrome. `home.html` is fully on the former,
   `shell.html`, `text.html` and `404.html` fully on the latter. The Tailwind
   config extends colours and fonts but **not** spacing, so the named scale is
   unavailable as a utility.
6. **The type scale is still not a scale.** 55 distinct `font-size` values
   across the eleven screen stylesheets, plus 25 more in `cv-print.css`; 19
   `line-height` values; 12 uppercase `letter-spacing` values. No ratio
   connects them.
7. **`article.css` was never updated.** It is 723 lines describing the old
   prose voice, kept alive only because `ledger/detail.css` loads after it and
   overrides most of it. Its radius declarations and its body-sans heading
   block are dead in the browser but live in the file. `.article-content h1`
   escaped the override and is still body sans at 600 / `1.4em`.
8. **About a third of `base.css`'s class selectors are dead.** `.home-panel`,
   `.home-panel-inner`, `.home-band-grey`, `.home-gateway`, `.home-hero-panel*`
   (including the stale container-query hero fit measured for Lora),
   `.home-portrait-*`, `.home-cv-*`, `.home-header-grid`, `.geometric-panel`,
   `.cv-box`, `.card-footer*`, `.card-thumbnail`, `.card-tag`, `.cat-link`,
   `.listing-card-grid--3`, `.serif-font`, `.font-headline`, `.font-editorial`
   — 33 of its 96 class selectors reach no markup. `.code-technical-sm` is the mirror
   case: a new token nothing consumes.
9. ~~**The CV timeline is stuck in the light palette.**~~ **Fixed 2026-09.**
   The chart now reads its lane colours from live CSS custom properties
   (`--timeline-*`) instead of Liquid-baked hex, and redraws on the
   `shell-theme-change` event, so it follows `data-theme` like everything
   else. Two related defects went with it: six event types were sharing four
   colours (employment collided with article, product with post), and the
   density bars and legend swatches read `--color-primary` / `--color-tertiary`
   — rebound to green on the CV by `.page-accent--green`, which flattened the
   chart into one hue. The lane palette is now its own categorical scale in
   `_data/themes/*.yml` under `timeline:`, deliberately outside the UI triad:
   see *Semantic and media colours*.
10. **`404.html` was not rebuilt.** It still carries `rounded-xl` on two
    buttons, `shadow-sm`, and a `bg-gradient-to-b from-primary
    to-primary-container` fill — three of the system's rules broken on one
    page.
11. **Navigation is still fully hidden.** A rich, deep site sits beNewsreader one
    hamburger at every breakpoint, so its structure is invisible on arrival.
    This survived the redesign untouched.
12. **Tailwind runs from the Play CDN in production**
    (`cdn.tailwindcss.com?plugins=forms,container-queries`), so utilities are
    unpurged, unversioned, and injected *after* the hand CSS. The redesign now
    depends on beating it twice: `base.css` re-specifies the filter input
    because the forms plugin paints it white in dark mode, and
    `ledger/detail.css` documents writing rules with two compound parts on
    purpose for the same reason.
13. ~~**`surface` still diverges between themes.**~~ **Fixed 2026-09.** Light
    had `surface == background == #ffffff`, so any component distinguishing
    the two — the nav, the filter popover — was invisible there. The ladder
    inversion gave `surface` the card value (`#fffdf9`) against a paper
    canvas, so the two now differ in both themes.
14. ~~**Light has no `sidebar_thumbnail` block.**~~ **Fixed 2026-09.** Light
    defines its own block now, so neither theme falls through to
    `_config.yml`.
15. **The Mermaid theme map is duplicated verbatim** in
    `_includes/page/mermaid.html` and `_includes/content-runtime/20-markdown.html`
    — nine `themeColor(token, '#hex')` fallbacks in each, byte-identical, with
    nothing keeping them in step.
16. **`renderArchiveCard`'s `showFooterDates` path is dead.** No layout passes
    the option, and `ledger/home.css` additionally hides
    `.ledger-card-foot .date-evolution` with CSS — a belt for a brace that is
    already off.
