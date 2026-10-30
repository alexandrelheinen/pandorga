# Changelog

## [Unreleased]

## [2.3.12] — 2026-10-30

### Fixed

- CR-24: deepen desk left/mid overlay further so pool title contrast clears ≥7:1 at 1440 while keeping the figure clearly readable (PLT-AC-100).

## [2.3.11] — 2026-10-30

### Fixed

- CR-24 follow-up: deepen desk soft overlay slightly so title/summary stay ≥7:1 after the 2.3.10 lighten (still well below 2.3.7; photo remains readable) (PLT-AC-100).

## [2.3.10] — 2026-10-30

### Changed

- CR-24: Hero name always band title + 2pt from `--type-section` / `--type-section-lg` (PLT-AC-98/99); soft overlay lightened so the figure reads while title/summary stay ≥7:1, target ~9–11:1 (PLT-AC-100). See [features/home-hero-scale-overlay.md](docs/features/home-hero-scale-overlay.md).

## [2.3.9] — 2026-10-30

### Fixed

- CR-23 follow-up: scope action glyph `+2pt` to the mobile icon-only row so desktop labeled pill boxes stay identical to 2.3.5 (PLT-AC-95).

## [2.3.8] — 2026-10-30

### Changed

- CR-23: Detail action glyphs +2pt (`calc(1rem + 2pt)`) without changing marker button box size (PLT-AC-95); mobile icon centering (PLT-AC-96); `padding-bottom: calc(var(--space-sm) + var(--space-xs))` (~12px) between action row and the “IN THIS TEXT” rule (PLT-AC-97). See [features/detail-action-icons.md](docs/features/detail-action-icons.md).

## [2.3.7] — 2026-10-30

### Fixed

- CR-22.4 follow-up: deepen desk soft overlay and use `#ffffff` hero title/summary ink so worst-case title contrast clears 7:1 on every pool photo at 1024/1440.

## [2.3.6] — 2026-10-30

### Changed

- CR-22.4: Home hero C4 — center Projects island in the desktop column (PLT-AC-88); soft edgeless full-bleed photo overlay with no panel behind copy (PLT-AC-89); denser stops for ≥7:1 title/summary contrast across the random pool (PLT-AC-90); family highlighter `--mk-h: 1.02em` / `padding-inline: 0.14em` (PLT-AC-91); default random hero draw when `hero_portrait` is unset, crops at `object-position: center` (PLT-AC-92); hero CTAs use marker wash with white ink allowed (PLT-AC-93); when actions wrap, CV alone on line 1 and contacts grouped on line 2 (PLT-AC-94). See [features/home-hero-c4.md](docs/features/home-hero-c4.md).

## [2.3.5] — 2026-10-29

### Fixed

- CR-22.3: stack Projects band uses `padding-block: 1.35rem 0` (~24px @390) to match B3 hero→title gap (was flush at 4px after zeroing `--space-3xl`).

## [2.3.4] — 2026-10-29

### Fixed

- CR-22.3 follow-up: zero stack portfolio `padding-block` so Projects title sits just under the hero like B3 (~24px gap at 390, not ~57px from `--space-3xl` band padding).

## [2.3.3] — 2026-10-29

### Fixed

- CR-22.3: B3 visual parity — pin optional `pandorga.home.hero_portrait` (website: DSC00571 seated full-figure) so live matches the approved mock image; hide the Projects `.ledger-section-banner` rule/blue segment so title top and hero→projects gap match B3; highlighter mark height `0.72em`; spotlight stop intensities aligned with B3 while keeping the centered pool (PLT-AC-84). Home crops stay `object-position: center` (PLT-AC-85); B3 mock used desk `58% 16%` / stack `72% 12%` — center framing differs numerically and is intentional.

## [2.3.2] — 2026-10-29

### Fixed

- CR-22.2: Home hero B3 pixel parity — masthead content width `1337.625px` with stage `padding-block` so hero/projects top aligns with approved mocks; title `margin-bottom: 1rem` and actions `margin-top: 1.5rem` restore B3 name/summary/button positions; stack hero bottom padding +5px; desk copy bottom pad +2.25px. Key measures (hero x/y/w/h, nameFs, name/summary/actions tops, projects left, topSpace) within ~2px of `measures-b3.json` at 390/768/1024/1440.

## [2.3.1] — 2026-10-29

### Fixed

- CR-22.1: Home hero name uses approved B3 clamps (~35px@1024 / ~40px@1440 / stack clamp) and must fit inside the panel (PLT-AC-86); summary/tagline forced light on the photo (specificity over legend); desktop hero panel uses B3 aspect ratios 454/736 and 637/693 (PLT-AC-87); featured home posters keep 16:9 instead of stretching to content height; stronger bottom scrim for stack legibility.

## [2.3.0] — 2026-10-29

### Added

- CR-22: Home hero B3 — portrait as centered spotlight background; desktop masthead places hero and Projects in two 50% content columns; stacked full-bleed hero below 1024px; config `pandorga.home.hero_overlay` (`vignette`, `pool`); gates PLT-AC-81…85. See [features/home-hero-b3.md](docs/features/home-hero-b3.md).

### Changed

- CR-21g (2.2.9): specimen card meta/copy/chips/CTAs restored to pre-2.2.7 sizes; inventory glyphs `calc(1.375rem + 6pt)`; title keeps −2pt (PLT-AC-80).

## [2.2.9] — 2026-10-29

### Changed

- CR-21g: Revert desktop home specimen card font-size -2pt reduction on meta line, description copy, chips/tags, and footer CTA buttons back to exact pre-2.2.7 token computed sizes (meta ~17.13px, copy ~18.93px, chips ~16.03px, foot CTAs ~16.03px) while keeping -2pt on the title (~24.64px). Reduce desktop (≥900px) inventory column icon glyph font-size by 2pt to `calc(1.375rem + 6pt)` (~32.2px). Mobile unchanged (PLT-AC-80).

## [2.2.8] — 2026-10-29

### Changed

- CR-21f: Home Projects band gains `home.limit_mobile` (default 6, mobile strip) and `home.limit_desktop` (default `all`, desktop column ≥900px). Home Projects section subtitle (`.home-section-note`) is constrained to the projects block width (column + card) on desktop so it no longer extends past the block; specimen card unchanged. Gate PLT-AC-79.

## [2.2.7] — 2026-10-29

### Changed

- CR-21e: Desktop Explore specimen (≥900px) plate +25% to ~383.3×215.6 (exact 16:9); card width follows plate + padding; specimen meta/title/copy/chips/footer type −2pt. Inventory glyphs and CR-21d column/label rules unchanged. Mobile unchanged (PLT-AC-78).

## [2.2.6] — 2026-10-29

### Changed

- CR-21d: Desktop Explore projects (≥900px) specimen plate is 16:9 at ~172.5×306.7; card hugs plate + padding with clean wrap; inventory column width equals button width; column-to-card gap ≤ 2× button gap; visible "Explore projects" label removed (aria-label on the inventory group) on desktop and mobile. CR-21c glyphs (+6pt, ≥70% fill) kept. Gate: 16:9 ±1% on plates, label hidden, column width/gap asserts (PLT-AC-77).

## [2.2.5] — 2026-10-29

### Changed

- CR-21c: Desktop Explore projects (≥900px) plate height ~60% of 2.2.4 (~217px) with `object-fit: cover`; inventory glyphs +6pt (`calc(1.375rem + 8pt)`, ≥70% of button height); inventory label and button stack right-aligned toward the specimen. Mobile unchanged (PLT-AC-76).

## [2.2.4] — 2026-10-29

### Fixed

- CR-21b: Desktop Explore projects inventory glyphs use the mobile CR-16 size (`calc(1.375rem + 2pt)` via the two-class selector at every breakpoint) so Material Symbols cannot inherit the body size; inventory buttons use a visible `--border-gentle` frame on every state; desktop specimen capped at 680px wide with plate `max-height: 45vh`, and the height-lock probe respects `--home-specimen-max-width` (PLT-AC-75).

## [2.2.3] — 2026-10-29

### Changed

- CR-21: Desktop Explore projects inventory (≥900px) updated to a shrink-to-fit vertical stack of logo-only square buttons using the exact mobile button chrome, borders, hover, and selected states without wide bands or contrast panel surrounds (PLT-AC-74).

## [2.2.2] — 2026-10-28

### Added

- CR-15: Hero longest line clamp divisor updated to upright Ancizar factor (~6.9em), with `--hero-name-fit` default updated to 6.9, so stacked hero titles fit cleanly within copy measure while desktop resolves near 73px (`--hero-name-max`) (PLT-AC-68).
- CR-16: Bumped project/inventory logo icon and sibling mark font-sizes by +2pt across all breakpoints (`calc(... + 2pt)`) (PLT-AC-69).
- CR-17: Home band section titles stepped up to `--type-section` below 768px and `--type-section-lg` from 768px, ensuring section headings clearly outrank featured project names (PLT-AC-70).
- CR-20: Detail reading-progress bar position changed to `position: fixed; top: 0` (bisect note: changed from 4.25rem added in 2.1.0 to stay fixed at viewport top regardless of sticky top bar hide-on-scroll state) (PLT-AC-72).
- Regression gate: Additive headless browser CI regression gate testing home, articles list, EN article detail, and PT post detail across 320, 390, 1440 viewports in light and dark themes for zero horizontal overflow, non-overlapping stacked elements, hero family bounding, and progress bar alignment (PLT-AC-73).

### Changed

- CR-19: Mobile article/post detail (<768px) meta and actions block redesign: published/updated dates stack vertically with breathing room; thin divider lines separate the block from the header plate and reading column; action controls (Back, Share, Cite, reading size, PDF) set as a `nowrap` equal-size icon-only row with visually hidden labels and accessible `aria-label`s fitting 320px viewports without overflow; clear gap added before prose and drop cap (PLT-AC-71).

## [2.2.1] — 2026-10-28

### Fixed

- CR-18: Mobile article/post detail meta restores `flex-wrap: wrap` so action buttons (Back, Share, Cite, reading size) wrap to the next row when dates and actions cannot share one line, preventing button crushing and clipping on narrow screens (regression from 2.1.0) (PLT-AC-67).

## [2.2.0] — 2026-10-28

### Added

- CR-10: Recalculated `.home-hero-title` cqi divisors for Ancizar Serif at -0.02em tracking (~5.55em phone family-line width, ~10.81em desktop full-name cap) (PLT-AC-62).
- CR-11: Fixed/list page titles (`.page-header-title`) default to upright by removing hardcoded `class="italic"` on `[data-content-header-title]`. Inline emphasis and marker wash apply only via `<em>` elements. `--type-page` and `--type-page-lg` tokens bumped so list titles are noticeably larger while detail titles remain unchanged (PLT-AC-63).
- CR-12: `.home-hero-family` drops `font-style: italic`, keeping primary color and raising marker strength to ~0.88× section alpha levels (PLT-AC-64).
- CR-13: Home hierarchy ladder adjusted so section titles dominate specimen names on mobile and desktop viewports. Raised `--type-section-sm` to 1.72rem and removed `.home-specimen-title` override to `var(--type-section)` at desktop breakpoints (PLT-AC-65).
- CR-14: Grouped title role marker selector in `assets/css/base.css` ensures `em` elements inside `.section-title`, `.page-header-title`, `.home-index-title`, `.card-title`, and `.ledger-card-title` receive the primary-color felt-marker wash (PLT-AC-66).

## [2.1.1] — 2026-10-28

### Fixed

- Mobile body weight (`body_weight_mobile` / `--weight-body-mobile`) now wins on viewports under 768px. The rebind lives in `theme-vars.html` after the theme token block so it is not overridden by the desktop `--weight-body` declaration (PLT-AC-57).

## [2.1.0] — 2026-10-28

### Added

- Site-configurable body weights under `pandorga.fonts.body_weight` (desktop default 300) and `pandorga.fonts.body_weight_mobile` (mobile default 350) wired into CSS custom properties (`--weight-body` and `--weight-body-mobile`) (PLT-AC-57).
- Static Marcellus SC label **“Explore projects”** above the Home Projects inventory (PLT-AC-61).

### Changed

- Default resolved typography stack switches to four families: Ancizar Serif for titles and top-bar wordmark, Ancizar Sans for body and taglines, Marcellus SC for labels, and Courier Prime for code. Cinzel Decorative and Newsreader defaults are removed from the default stylesheet request (PLT-AC-56).
- `--font-content-title` uses `--font-title` (Ancizar Serif) instead of body face (PLT-AC-56).
- On the home hero, `.home-hero-family` renders in italic, primary color, with a highlighter mark wash scaled to ~40% intensity of detail action buttons, while `.home-hero-given` stays upright in default ink (PLT-AC-58).
- Heading and title selectors in ledger CSS no longer apply `text-transform: uppercase`, and title italics are restricted to `.home-hero-family` and `.section-title em` / `.page-header-title em` (PLT-AC-59, PLT-AC-60).
- On viewports at or above 900px, the Home Projects bench places the inventory column to the left of the specimen. Inventory buttons become logo-only with enlarged icon marks, keeping accessible labels (`aria-label`) and tooltips on hover/focus (`title`) (PLT-AC-61).

## [2.0.4] — 2026-10-28

### Fixed

- Mobile article top compresses dates and action buttons into one band and closes the gap before the reading column.
- Mobile top bar is shorter and hides on scroll-down (shows on scroll-up, focus, or Explore open).
- Home hero summary uses a ~65ch measure on desktop.
- Home section "View all" sits beside the section title instead of at the far right of the band.

## [2.0.3] — 2026-10-25

### Fixed

- Entry titles on the Articles, Sources and Bibliography pages use the Rascunhos size at every width. The Articles rows and Sources cards were a step smaller and shrank again below 768px, and the Bibliography cards were a step smaller (PLT-AC-55).

## [2.0.2] — 2026-10-25

### Added

- The home hero summary has its own file, `content/pages/home/summary.md`, editable in Studio as "Hero summary" under Presentation, so the site presentation and the CV page summary can differ. Without the file the hero keeps showing `content/pages/cv/summary.md`; saved empty, the hero shows no summary. The Studio CV summary entry for the public page is now labelled "CV page" (PLT-AC-54).

### Changed

- The object-store publish syncs `collections/`, `data/`, `pages/` and `media/` as parallel jobs, prints each job's log in a fixed order, and uploads `manifest.json` last, only after every job succeeded. Upload, delete and verification semantics are unchanged (PLT-AC-53).

## [2.0.1] — 2026-10-24

### Fixed

- Home article cards set their tags and "Read" on one row, like the featured card, and every card's top rule uses the Articles accent instead of rotating through the palette, which drew the second card in the secondary hue (PLT-AC-52).
- A home band header whose kicker, title and note are all saved empty is removed with its rule instead of leaving an empty ruled strip; the band keeps an `aria-label` (PLT-AC-52).

## [2.0.0] — 2026-10-24

### Added

- Section texts are editable in Studio from `content/pages/headers.yml`: a projects page form (title, kicker, note, home link label and the two projects page banners), a `cta` link label for every page on the home, a `note` for Sources and Network, and the CV section titles, timeline title and Contact label. The Sources, Network and Bibliography home panels show each page's headers title and, under it, its `note`. A field left out keeps the theme default; a field saved empty renders nothing and a hidden heading keeps its default as the region's accessible name. Studio saves an emptied field as `""` (`keep_empty`), and the runtime fills these texts from `pages/headers.json` for content-agnostic shells (PLT-AC-50).

### Changed

- `pandorga new`, getting started and the deploy and upgrade guides pin `gem "pandorga", "~> 2.0"`; `~> 1.3` does not resolve 2.0.0.
- **Breaking.** The home hero plate is 16:9 at every width. From 1024px the name sets on two lines in a 46% copy column and the photograph takes the rest of the row, as tall as the copy and at least 15rem, with `object-fit: cover`; below 1024px the plate spans the column. The export writes 16:9 `variants/<stem>-{480,960,1440}.jpg` for each hero photograph with the project thumbnail generator and lists only 16:9 variants in `portraits.json`. See docs/upgrading.md (PLT-AC-51).
- Every page sits on one canvas (`--color-canvas`, from `neutrals.canvas`, else `panel_contrast`) with square 1px hairline cards on the card surface and a 2px accent rule on featured cards. Home bands set the title and "View all" on one row with the note below; band titles, card titles, excerpts and metadata step down below 768px, metadata uses the mono face, and excerpts clamp to 3 lines on phones and 4 from 768px (PLT-AC-49).
- On phones the featured article opens with its image edge to edge, Rascunhos show three untilted cards (two side by side, the third a landscape card across both columns; the tilt stays from 768px), project posters run edge to edge, and the reading column and its sidebar have no box (PLT-AC-49).
- The Sources, Network and Bibliography panels open with the title and Open link above the illustration. The top bar sits on the translucent canvas with a hairline, and the theme and menu buttons are bordered squares (PLT-AC-49).
- Text calls to action ("View all", "Open", "Read", "Repository", "Article") carry the strong highlighter mark instead of an underline (PLT-AC-49).

### Removed

- **Breaking.** `pandorga.home.hero_landscape`, home front matter `hero_landscape`, the `landscape` field of a `portraits.json` entry, the narrow-viewport hero draw and its preload, and the 3:4 hero variants (PLT-AC-51).
- The radial blur pools, the decorative shards outside the footer, and the frame corners inside cards (PLT-AC-49).

### Fixed

- From 1024px the hero layout rules apply: the base plate rules (`max-width`, `position`, `aspect-ratio`) used to follow them in `home.css` and win on source order (PLT-AC-51).
- From 1024px to 1279px the top bar no longer runs the section links under the wordmark and the theme and menu buttons. The links stay in the menu until 1280px, and the rail gap is tighter up to 1439px (PLT-AC-49).

## [1.14.1] — 2026-10-20

### Fixed

- Hovered Back, Share, Cite, and reading-size buttons on article pages meet 4.5:1 in the light theme; the green section text on the gray hover mark was 4.48:1 (PLT-AC-46).

## [1.14.0] — 2026-10-20

### Changed

- Pills, tags, facets, filters, and buttons use a borderless felt-pen highlighter wash with deterministic nth-child geometry variants, quiet and strong mark strengths, solid fill on hover, and section-accented active rail links (PLT-AC-46).
- The CV timeline pans in time: drag the chart, use the ‹ Today › controls, or focus it and use the arrow keys, Page Up/Down, Home and End. Zoom, resize and lane toggles keep the date at the center in view. Selecting a period now takes Shift+drag (a plain drag pans) (PLT-AC-47).

### Fixed

- The CV timeline no longer handles an input twice when the inline placeholder boots before the timeline data loads; zoom buttons and resize were affected before this change (PLT-AC-47).

## [1.13.0] — 2026-10-19

### Added

- `pandorga export` and the new `pandorga thumbnails [root]` command write 16:9 center-cropped width variants (`variants/<stem>-{480,960,1440}.jpg`, progressive JPEG at quality 82, stripped of metadata, never upscaled) beside each local `/media/...` project thumbnail when ImageMagick is installed (logging one warning otherwise), export `thumbnail_srcset` on project front matter and `writing_index.json`, and render `srcset` and `sizes` on project cards and the home specimen (PLT-AC-44).

## [1.12.0] — 2026-10-19

### Changed

- `pandorga install-functions` fills the Studio tag pickers from the site's `_config.yml` → `pandorga.taxonomies` (with `min` and `max`), falling back to a page's `taxonomy`, then applies `studio.overrides.yml`. The gem's `studio/schema.yml` no longer ships a site's tag vocabulary; a collection without one gets an empty picker and a build warning (PLT-AC-43).

## [1.11.0] — 2026-10-19

### Fixed

- Home listing bands keep their kicker and note on sites built with
  `shell_content_agnostic: true`; the slots are always in the HTML and the
  runtime fills them from `pages/headers.json` (regression from 1.10.0)

### Changed

- On the home projects bench at or above 900px, the specimen column takes 35%
  of the band (at least 20rem) and the filing rack 45% (at least 21rem) across
  one `--space-xl` column gap from the band's left edge, keeping the 16:9
  plate at 60% of its previous height. The specimen sets the bench height (the
  tallest project), and the rack rows share that height, each capped at 1.6
  times its minimum
- Below 900px the project icon-strip glyphs and the plate badge glyph grow to
  1.375rem
- The home project specimen title uses `--type-section` from 900px and
  `--type-card-lg` below it; inventory rack titles use `--type-card`
- The home specimen meta strip wraps instead of clipping on narrow viewports
- The home hero summary uses `--color-legend`, the same ink as the other
  description texts

## [1.10.2] — 2026-10-16

### Changed

- On the home projects bench, each inventory row shows the project icon mark
  (or initial fallback), optional index and label strip, and title, without a
  thumbnail poster, tagline preview, or attached-resource icons. On desktop
  (`>= 900px`) each row fits that two-line body and square icon mark, and the
  specimen height matches the inventory stack
- Project hero action pills keep their label text free of underlines at rest
  and on hover

## [1.10.1] — 2026-10-14

### Changed

- On article, draft, product, and project detail pages, the category pills
  keep `--space-md` above and below, on a phone and in the desktop dossier
- The description under the title stays the body face at `--type-prose`,
  and uses `--color-on-surface-variant`, the muted ink of secondary text
- On a phone, the contents dropdown links use `--type-prose`. The gap above
  that dropdown is `--space-sm`. The gap under it stays `--space-md`, the
  same inset as the pills. The date text keeps `--space-sm` under its own
  rule and above the action rule

## [1.10.0] — 2026-10-14

### Added

- A portrait entry in `pages/home/portraits.json` may set `landscape`, a
  16:9 URL. At or below 767px the home hero draws at random from the
  entries that have one and paints that file. `pandorga.home.hero_landscape`
  is the fallback when none do. The phone plate stays 16:9

### Changed

- On article, draft, product, and project detail pages, category and tag
  chips sit above the title
- On a phone, the detail title sits closer to the nav (`pt-10` to
  `--space-xl`). The gaps inside the title block and before the contents
  list each drop one spacing token. The contents list keeps `--space-md`
  under it, inside the title plate. The stacked gap between that plate
  and the reading column is `--space-md`. Desktop column gutter stays
  2rem, and 3rem from 1024px
- Article and draft section headings grow by 2pt on `h2` and 1pt on `h3`.
  The same sizes apply to project and product bodies

## [1.9.1] — 2026-10-14

### Fixed

- The article description under the detail title uses `--type-prose`, the
  same size as the body text. Family, weight, color, and spacing stay as
  they were
- Bordered and boxed read-more pills do not underline the label.
  Plain text read-more links stay underlined. Focus still shows the
  outline

## [1.9.0] — 2026-10-13

### Added

- Optional `pandorga.home.hero_landscape` (home front matter
  `hero_landscape` overrides it): a 16:9 image for viewports at or below
  767px, via `<picture>`, shown whole in a 16:9 plate

### Changed

- Without that key the phone hero plate stays 3:4. It no longer cover-crops
  the portrait into a 4:3 band
- The hero image keeps `fetchpriority="high"`. A configured landscape file
  is preloaded on narrow viewports. The portrait probe sets `fetchPriority`
  to `high`, applies `srcset` before `src`, and the plate draw starts with
  the other home fetches
- Home links `tailwind.css` before the icon scripts so that sheet is not
  held behind parser-blocking script

Text faces still load after the first paint with `display=swap` and the
metric-matched fallbacks from 1.8.4. One listing shell still serves every
detail URL.

## [1.8.5] — 2026-10-13

### Fixed

- Home hero `sizes` nudged above the plate width so 1.75–2× DPR picks a
  sharp 3:4 variant; document that hero variants must be portrait fills

## [1.8.4] — 2026-10-12

### Fixed

- Metric-matched local fallbacks for Cinzel Decorative, Cinzel, Newsreader,
  Ancizar Serif, and Marcellus SC so `display=swap` does not reflow the home
  hero (CLS)
- Home hero `portraits.json` includes `srcset` / `sizes` when
  `variants/<stem>-{480,960,1440}.jpg` exist under the hero folder

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.8.3] — 2026-10-12

### Fixed

- Detail pages load MathJax only when a TeX block nears the viewport (not on
  every article open), then typeset visible blocks first; below-fold formulas
  follow via IntersectionObserver with yields between blocks
- Listing layouts (articles / blog) no longer pull the MathJax script
- Long detail bodies mount in batches so the opening can paint before the
  full DOM lands
- Figure and cut-in images use `decoding="async"` plus width/height hints
  with existing `loading="lazy"`

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.


## [1.8.2] — 2026-10-12

### Fixed

- Home listing CTAs: more space between the label and its underline
- Home index panels (Sources / Network / Bibliography): shared plate flex and
  card-scale titles so the three cards align
- Articles archive: `random` sort shows **Order: random** (was falling back to
  last revised)
- Listing masthead tag lines (Rascunhos, Sources, peers) use body size instead
  of micro / mono
- CV contact tiles: quieter badge and name type
- Dates / meta (`--type-meta`) +2pt; content titles (`--type-title`) +10%;
  top-bar wordmark +25%
- Theorem / proof heads sit inline with the opening sentence (no line break
  after the name / **Proof.**)
- Proof QED square (`□`) is +2pt over the body size

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.8.1] — 2026-10-12

### Fixed

- Theorems are bare (no gray plate); only proofs carry the surface band
- Proof gray bleeds to the edges of `.text-page-main` while body text stays
  on the reading measure
- Proofs prefix **Proof.** from the runtime, like theorem heads — authors
  no longer write `*Proof.*` in the body

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.8.0] — 2026-10-12

### Added

- Theorem and proof Markdown wrappers in the content runtime, same
  `markdown="1"` contract as `article-note` and `poem`:
  - `<div class="theorem" name="Corollary 1" description="nadir camera" markdown="1">…</div>`
    builds the head from `name` / `description` and italicizes the body
  - `<div class="proof" markdown="1">…</div>` wraps a proof and places a
    QED square on the last line
- Full-column styles for `.theorem` and `.proof` in `article.css`
- Render-parity fixtures `theorem.json` and `proof.json`

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.6] — 2026-10-12

### Fixed

- A long inline formula scrolls inside the article column below 768px.
  Display math was already contained, and a 390px phone still measured
  scrollWidth 667 because `mjx-container` without `display="true"` is
  `display: inline` and cannot scroll. Below 768px that box is
  `inline-block`, `max-width: 100%`, `overflow-x: auto`, and
  `overflow-y: hidden`. Wider viewports keep it inline. `html` and
  `body` do not set overflow.

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.5] — 2026-10-12

### Fixed

- A display equation scrolls inside the article column. On a 390px
  viewport a MathJax display box about 455px wide was stretching the
  document to a scrollWidth of 667, so the page moved sideways and the
  sticky header scrolled with it. `mjx-container[display="true"]` and
  `mjx-container[jax][display="true"]` are `max-width: 100%` with
  `overflow-x: auto` and `overflow-y: hidden`. Tables, figures, and
  article SVG are bounded to the column. Mermaid still scrolls inside
  `.mermaid`. `html` and `body` do not set overflow, so the sticky
  header still sticks.
- A detail URL served by the listing shell had two `h1` elements: the
  listing title (Articles, Rascunhos, Projects, Curriculum) and the
  entry title. While the entry is showing, the listing heading is not
  an `h1`. The document title is the entry title, and `html` `lang`
  follows the entry (`en`, `pt-BR`, `fr`, `es`). Articles, posts,
  projects, and products.

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.4] — 2026-10-12

### Fixed

- The footer imprint separator uses `outline` on the panel step.
  `outline-variant` on that panel is 1.80:1 in light (`#b8b8b8` on
  `#f4f4f4`) and 1.93:1 in dark (`#45454c` on `#141418`). `outline`
  on the same panels is 6.08:1 and 5.95:1.

### Changed

- Unused selectors are gone. `assets/css/ledger/home.css` drops
  `.home-hero-pandorga-svg` (25 bytes). The hero SVG uses
  `home-hero-art-svg`. `assets/css/ledger/detail.css` drops 916 bytes:
  the author byline suppressor and the `.table-csv` companions. No
  template or runtime emits either class. 941 bytes in all.
- The one-shot key backfill is gone (`scripts/content/backfill-content-keys.rb`,
  3,432 bytes). Nothing called it.
- The watch-path test that read `docs/ops/cloudflare.md` is gone
  (1,230 bytes). That path is not in the tree.
- Deploy notes pin `~> 1.3` and tag `v1.7.4`. The Pages watch paths
  include `*` and exclude `content/*` and `docs/*`.

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.3] — 2026-10-12

### Fixed

- A detail URL is the listing shell again. The build does not write a
  static page per article, post, project, or product, and those URLs
  are not in the sitemap. The published `_redirects` keeps the splat
  200 rewrites onto the listing shells, and adds any line the source
  file is missing. The source file is unchanged. The client sets the
  canonical link and `og:url` when it renders the entry.

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.2] — 2026-10-11

### Fixed

- A published article, post, project, or product is a static page at its
  public URL. The sitemap lists that URL. The static canonical and
  `og:url` are the detail path, and `data-listing-path` stays the
  listing. Articles emit `Article` JSON-LD. Posts emit `BlogPosting`.
- The build writes `_redirects` into the output and drops the splat 200
  lines that sent those URLs back to the listing shell. The source file
  is unchanged. Publish the built file.
- A listing page's static `<h1>` is the title from
  `content/pages/headers.yml`, or the page title. It is not the word
  Loading.
- The top bar is a `<header>`. The section links are one
  `<nav aria-label="Sections">` inside it.
- Dark theme text on the tertiary container is `#ebe7c3` on `#6a684f`
  (4.52:1). The container colour is unchanged.
- The hero portrait gate crops the runtime through `pickHeroPortrait`.

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.1] — 2026-10-11

### Fixed

- Decorative Material Symbols beside a label no longer expose the ligature
  (`arrow_left_alt`, `shuffle`, a contact icon, a missing-media mark).
  The public detail path and the private layout agree. Nine spans.
- The shell published two `og:image` properties. The second meta element
  carried both `name="image"` and `property="og:image"`. `name="image"`
  stays on its own element, so a page has one Open Graph image.

### Changed

- Unused ledger selectors are gone. `assets/css/base.css` drops 2,041
  bytes: `.page-title` (404), `.ledger-marker--primary` (616),
  `.ledger-card--edge-*` (462), and `.ledger-section-rule` (559).
  `assets/css/ledger/home.css` drops 577 bytes of rules that no band
  uses: `.home-band--ruled` (310), `.home-index-shard--gamma` (163),
  and `.home-index-note` (104). `assets/css/global-link.css` drops the
  `.post-content` hover selector (23 bytes). None of them matched a
  template, the runtime, or current content. 2,641 bytes in all.
- Comments that a font rename had rewritten, eating the letters inside
  the word "behind", read "behind" again. 45 occurrences in 21 files.

No `pandorga:` config keys were added or renamed. Font roles and the
ledger fallbacks are unchanged.

## [1.7.0] — 2026-10-10

### Added

- A site can name its typefaces under `pandorga.fonts`. `title`, `body`,
  and `mono` take a Google Fonts family, or a map with `family` and
  optional `weights` and `italic`. `label` and `subtitle` are optional.
  Omitted roles keep Cinzel Decorative, Newsreader, and Courier Prime.
  The text faces still load after the first paint.

## [1.6.9] — 2026-10-10

### Fixed

- Home list hydration no longer fills every band in one turn. The project
  specimen measurement yields between projects, each band starts on its
  own turn, and each home section introduction yields before it is
  parsed. Dates reuse one formatter. The lists still render.

No `pandorga:` config keys were added or renamed.

## [1.6.8] — 2026-10-10

### Fixed

- Home bands and the other listing pages fill again. Their scripts sit in
  the page and used to run before the runtime existed, then return. The
  titles stayed in the HTML and the lists stayed empty, on the phone and
  on the desktop. Lighthouse scored that empty document. Those scripts
  now start when the runtime is assigned. The runtime stays after the
  page. The static hero summary, the deferred text faces, the deferred
  markdown library, and the named icon subset stay as they are.
- CI loads the built example home and fails when the projects, articles,
  or posts band has no items after load, on a phone viewport and on a
  desktop viewport.
- On a phone, the featured card in the home Articles band has more space
  above its text. The other article cards keep their padding. Article
  titles in that band are 2pt larger.
- On the Rascunhos page, the licence sits under the entries again below
  1024px. The per-page stylesheet split had stopped loading the sheet
  that ordered it, and the page's own `display: block` put it back on
  top. The order now lives on the sheet the blog layout always loads.

### Changed

- The site and Studio launcher icons are the same stamp, on the same
  plate, in the same pastel triad. The stamp is the same size on both,
  with the same padding, at 512, 192, 180, and 32. Studio adds a small
  badge inside that stamp. The build writes `/site.webmanifest` and
  `/studio.webmanifest` with maskable icons, so Android masks both to
  one shape and one visual size. The shell links the site manifest.
  Studio links the studio manifest.

No `pandorga:` config keys were added or renamed.

## [1.6.7] — 2026-10-10

### Fixed

- Text faces are requested after the first paint and before the load
  event. A blocking sheet held first paint on the font host. The load
  event held the hero summary until images finished, so the live home
  scored about 50 while the example, which has no summary, scored 98.
- The icon face names the icons it needs. The full variable file is about
  a megabyte, and decoding it blocked the main thread on the live home.
- The project inventory region has a role to match its accessible name.
- Lighthouse measures `examples/full`, whose home includes a static hero
  summary, the element a real site paints largest.

No `pandorga:` config keys were added or renamed.

## [1.6.6] — 2026-10-10

### Fixed

- The text faces and the flag stylesheet are requested after the load
  event. A head link let a fast connection finish them before the largest
  paint, and the simulator then counted those files as part of that paint.
  The same templates scored 87 on the release run and 97 on the pull
  request. `font-display: swap` stays.
- The markdown library loads with `defer`. The example home is already
  HTML, so that script does not block the parser.

### Changed

- A release below 90 does not publish. A bug-fix release whose notes
  include `LIGHTHOUSE_BUGFIX=1` may still publish from 75 to 89.

No `pandorga:` config keys were added or renamed.

## [1.6.5] — 2026-10-10

### Fixed

- The example home measured like the public site: compressed responses,
  served concurrently. The stock one-thread HTTP/1.0 server was scoring
  the same templates in the 70s while the live site on 1.6.3 scored 97.
- The Material Symbols face is about a megabyte. It is no longer linked
  from the head. The shell adds that sheet after the load event, so the
  simulator does not wait on it for the largest paint. The text font
  sheet and the flag stylesheet use print media and apply on load.
- The icon box stays 1em.

### Changed

- Lighthouse mobile thresholds apply to releases. Pull requests and merges
  to main only warn. The release build checks out the tag and fails below 75.

No `pandorga:` config keys were added or renamed.

## [1.6.4] — 2026-10-10

### Fixed

- The Material Symbols stylesheet no longer blocks first paint. It loads
  as print media and is applied on load. The icon box stays 1em, and its
  size stays inherited, so the Google sheet cannot restyle it after paint.
- The content runtime, including marked, comes after the page so the
  hero is in the document before that script. A home band's kicker, title,
  and note from `content/pages/headers.yml` are in the HTML.
- The hero subtitle from `content/pages/headers.yml` is in the HTML.
  Leaving that line empty until script runs moved the portrait.
- On a phone the hero band is shorter, so the first section title stays in
  the first viewport. That title was the late LCP element.

### Added

- Lighthouse mobile is a release rule. A stable release scores 90 or above.
  A score from 75 to 89 is acceptable only to ship a bug fix, and an urgent
  performance campaign must then bring the score back to 90 or above.
  Below 75 is never acceptable. CI runs one mobile pass on the example home.

No `pandorga:` config keys were added or renamed.

## [1.6.3] — 2026-10-10

### Fixed

- The Google Fonts stylesheet is linked with the ledger sheets again. In
  1.6.2 it sat above the preload script, and that script cannot run until
  earlier stylesheets finish, so first paint waited on fonts.googleapis.com.
  The font hosts are still preconnected before that script. The static
  summary and the serif fallback are unchanged.

No `pandorga:` config keys were added or renamed.

## [1.6.2] — 2026-10-10

### Fixed

- The home hero summary is rendered from `content/pages/cv/summary.md` at
  build time. It was painted from JSON, so the paragraph's LCP was almost
  all render delay.
- The summary no longer reserves six empty lines. That box shifted the
  call to action when the real paragraph arrived.
- The body face is requested before the ledger sheets. `font-display: swap`
  stays. The fallback is Georgia, then serif, so the swap does not reflow
  the summary from a sans.

No `pandorga:` config keys were added or renamed.

## [1.6.1] — 2026-10-10

### Fixed

- The articles featured slot reserved 16rem whenever it was empty, so page 2
  and later kept a blank band between the header rule and the filter. The
  reserve now lasts only until the listing decides. A page with no specimen
  collapses that slot.

No `pandorga:` config keys were added or renamed.

## [1.6.0] — 2026-10-10

### Added

- `/sitemap.xml` lists the generated pages. `/robots.txt` allows the public
  site, skips `/studio/`, and names the sitemap. Both use
  `pandorga.identity.url` when it is set, otherwise `site.url`.
- JSON-LD `WebSite` and `Person` in the shell, from `identity.name` and the
  optional `identity.url`. `site.description` is included when it is set.
- Hero portrait entries may include optional `srcset` and `sizes`. A portrait
  that only has `src` is unchanged.

### Changed

- The home subtitle and summary are requested before the stylesheets and
  painted without a "Loading..." swap. Article rows, CV sections, and empty
  home bands keep a reserved box until the real content replaces it.
- The hero subtitle stays at `--type-body`, the same size as the summary.
- `.writing-revised` uses the solid variant ink. The transparent mix was
  3.69 and 3.90 on the light paper.
- A selectable project inventory row is a `button`.
- Utilities ship as `assets/css/tailwind.css`. The shell no longer loads the
  Tailwind Play CDN. Each layout links the shared chrome and its own ledger
  sheet, not every sheet.

No `pandorga:` config keys were added or renamed. `srcset` and `sizes` are
optional fields on objects in `pages/home/portraits.json`.

## [1.5.1] — 2026-10-10

### Fixed

- The shell has a "Skip to content" link. When `site.author` is blank, the
  home link's accessible name uses `pandorga.identity.name`, then the top-bar
  wordmark, instead of a bare dash. The footer wordmark uses the same
  fallback. A site that sets `site.author` is unchanged.
- `pandorga doctor` says when `pandorga.pages` is missing, and says when the
  list is empty.
- `./scripts/validate.sh` fails if a listed gate file is missing.

### Changed

- Getting started and the README name the scaffold pin `~> 1.3`.
- `pandorga new` comments the `v1.5.0` tag.
- Home CSS drops an empty `@media (min-width: 768px)` block and the unused
  `.home-profile-summary` rules.
- Chord chart and transcript include comments are English. The visible
  transcript labels are unchanged.

No `pandorga:` config keys were added or renamed.

## [1.5.0] — 2026-10-10

### Added

- Optional `pandorga.identity.first_name` and `pandorga.identity.last_name`.
  The home hero uses them as the given name and the family name. The top
  bar shows `first_name`. `last_name` is kept whole, spaces included.
  Omit either key and that part still comes from splitting `identity.name`
  on the first space, as in 1.4.9. `identity.name` stays required.

### Changed

- The home hero subtitle uses `--type-body`, the same size as the summary
  under the name.
- Below 768px the hero name is 3pt larger, and a wrap breaks only between
  the given name and the family name.

## [1.4.9] — 2026-10-09

### Changed

- Article `##` uses the card step (`--type-card-lg`). `###` sits halfway
  between that step and the reading size. `####` matches the reading size
  (`--type-prose`).

## [1.4.8] — 2026-10-08

### Changed

- Home project bench: specimen and inventory share equal ~45.6% columns;
  inventory thumbnails fill row height at 16:9; list titles, copy, and
  resource marks retuned (neutral gray icons, tighter type)
- Specimen tagline flexes into spare card height and ellipsizes with a
  proper "…" (CSS line-clamp was hard-clipping mid-glyph)

## [1.4.7] — 2026-10-07

### Fixed

- Studio keeps the editor focused while the content-pipeline chip is spinning.
  Status polls patch the toolbar chip instead of rebuilding the shell.
- Home draft cards use 16:9 thumbnails and are 20% shorter on desktop and mobile.

## [1.4.6] — 2026-10-07

### Fixed

- Pipeline config resolution no longer swallows `_config.yml` read failures as
  a silent “unconfigured”; returns a clear message when
  `pandorga.content.workflow` is missing
- Studio chip surfaces pipeline-status API errors on boot, not only after Save

### Added

- Gate `test-studio-pipeline-config.mjs` for `parseContentWorkflowFromConfig`

## [1.4.5] — 2026-10-07

### Changed

- Studio pipeline chip is always visible (between Theme and Revert); toolbar
  Delete control removed
- Pipeline workflow name comes from `_config.yml` → `pandorga.content.workflow`
  (not a Pages secret); env override remains optional
- Pipeline status without `sha` returns the latest run on the branch

## [1.4.4] — 2026-10-07

### Added

- Studio content-pipeline status: after Save in production, poll GitHub Actions
  for the content workflow on the commit SHA (Waiting / Exporting / Live /
  Failed). Local Export keeps a real reexport button with the same sync colors.
- `GET /api/studio/pipeline-status?sha=` on the Studio Function

### Changed

- Studio docs: document the pipeline indicator, Actions read on the PAT, and
  toolbar states

## [1.4.3] — 2026-10-07

### Changed

- Studio format toolbar buttons (H1–H4, icons, case toggles) and the color
  select share one locked square size

## [1.4.2] — 2026-10-07

### Changed

- Home inventory resource badges are non-clickable indicators, stacked from the top

## [1.4.1] — 2026-10-07

### Changed

- Studio top-bar brand: icon-only on mobile; no gray current-page plate on desktop

## [1.4.0] — 2026-10-07

### Added

- Studio collection rows: bordered Edit/Delete icon ops with delete confirm
- Studio media library: bordered Copy/Delete icon ops inside row cards; delete
  commits through the file DELETE API
- Home project inventory: vertical code / article / site resource badges when
  those fields are present; rack column widened slightly

### Changed

- Studio chrome: redesigned top bar, theme menu, equal-width action tools,
  title-face wordmark sized to the mark, Media library shell aligned with
  collection lists
- Studio writing lists (Articles, Rascunhos): remove category filter chips and
  per-row taxonomy column
- Studio Media library: drop the disclaimer under the title
- Home project bench: drop ongoing/completed status pills from the specimen strip

### Fixed

- Studio toolbar Theme/Revert/Save/Export share one locked height; disabled
  tools mute color instead of opacity so Revert does not look shorter
- Studio sidebar keeps scroll position when expanding nav groups
- Studio brand home no longer swallows the top-bar action cluster

## [1.3.31] — 2026-10-07

### Fixed

- Studio toolbar disabled tools no longer use opacity (which made Revert look
  shorter than Theme/Save/Export at the same box height)

## [1.3.30] — 2026-10-07

### Fixed

- Studio top-bar Theme/Revert/Save/Export share one locked height box
  (min/max/height), including the Theme menu wrapper button

## [1.3.29] — 2026-10-07

### Changed

- Studio top-bar wordmark uses the title face, sized so the first S matches the mark height

## [1.3.28] — 2026-10-07

### Changed

- Home project inventory rows widen slightly and show a vertical column of
  square code / article / site badges when those fields are present

## [1.3.27] — 2026-10-07

### Changed

- Remove category tag pills and taxonomy column from Articles and Rascunhos lists

## [1.3.26] — 2026-10-06

### Changed

- Media library rows are single bordered cards with Copy/Delete inside, matching collection list ops

## [1.3.25] — 2026-10-06

### Changed

- Drop the Media library disclaimer under the title

## [1.3.24] — 2026-10-06

### Fixed

- Studio top-bar tools share one height again: a later `height: 100%` rule on
  direct `.btn-tool` children was overriding the fixed size and growing
  Revert/Save/Export to the brand line while Theme stayed shorter

## [1.3.23] — 2026-10-06

### Changed

- Media library rows use bordered Copy and Delete icon buttons; delete confirms
  then commits removal via the existing Studio file DELETE API

## [1.3.11] — 2026-10-06

### Fixed

- Studio SPA rebuild embeds the real Clerk Frontend API host again (was baking
  `clerk.example.com` into `studio/`); Vite refuses placeholder publishable keys

## [1.3.10] — 2026-10-06

### Fixed

- Home specimen height is measured from the tallest project and locked, so
  swapping projects no longer resizes the bench or the inventory; taglines
  and wrapping chips still fit without clipping

## [1.3.9] — 2026-10-06

### Changed

- Studio header uses a compact icon toolbar with a light / dark / system theme
  menu; mobile collections toggle matches the public site menu icon
- Left collections aside stays visible from 961px; navigation groups list
  References before Portfolio
- Expo launcher icons split `assets/studio/` (hex mark) vs `assets/website/`
  (square site logo); hex frame is stroke-only with no gray fill plate

## [1.3.8] — 2026-10-06

### Fixed

- Home specimen grows with its tagline and wrapping tag chips instead of
  clipping under a fixed height; pills stay one line (row wraps whole chips)
- Specimen strip above the plate uses the projects label chrome at a larger
  step so it matches the featured scale

## [1.3.7] — 2026-10-06

### Added

- Home projects band specimen bench: project specimen, rack card, and tape
  blocks, with inventory rows and glyph/initial fallbacks when an icon is
  missing

### Fixed

- Specimen stays half-width and 16:9; title always sits below the plate with
  roomier copy and links; drafting tape removed from the home layout

## [1.3.6] — 2026-10-05

### Fixed

- Home specimen is taller so project tags are not clipped, with more space
  between the poster and the project title

## [1.3.5] — 2026-10-05

### Fixed

- Home specimen height is CSS-fixed (no ResizeObserver jump when switching
  projects); mobile icon strip always reserves six compact slots; desktop
  inventory sits in a panel over the tiled band

## [1.3.4] — 2026-10-05

### Fixed

- Home portfolio mobile inventory is a single row of project-icon buttons
  (desktop index styles no longer override the phone layout)

## [1.3.3] — 2026-10-05

### Changed

- Home portfolio inventory is an index folio (number, thumb, title, project
  icon) with a borderless specimen; drafting marks stay on the poster only
- Specimen meta shows project tags instead of label/status
- Mobile selector strip and session-sticky random specimen pick from 1.3.2
  polish remain

## [1.3.2] — 2026-10-05

### Fixed

- Home inventory rows are selectable, height-synced to the specimen, and keep
  16:9 thumbs flush in flex media shells
- Studio list surfaces use the themed panel background

## [1.3.1] — 2026-10-05

### Changed

- Home portfolio band is a specimen + inventory bench (16:9 media) instead of
  an equal card grid
- Projects listing lead shows a Featured chip

## [1.3.0] — 2026-10-05

### Fixed

- Object-store publish fails fast when `PANDORGA_SITE_ROOT` is unset and the
  script runs from the pandorga gem (no more silent skip of `content/media`)
- `pandorga publish` exports `PANDORGA_SITE_ROOT` even when delegating to a
  site-local `publish-content-to-r2.sh` wrapper

## [1.2.4] — 2026-10-05

### Fixed

- An omitted `pandorga.content.backend` keeps a configured `base_url` or legacy `content_api_base_url` as an object-store origin. `static` remains the default only when no public URL is set, and an explicit `backend: static` still wins.

## [1.2.3] — 2026-10-05

### Changed

- Home portfolio cards use a denser equal grid (projects listing layout untouched)
- Corrects the 1.2.2 mis-target that compacted the projects index instead of the home band

## [1.2.2] — 2026-10-05

### Added

- Blog listing chrome follows `pages[].language` (`en` default; `pt-BR` for Portuguese UI strings)

### Changed

- Home draft cards are taller (~40%) so excerpts stay readable
- Full example blog page is `Rascunhos` with `language: pt-BR`

### Removed

- Mobile nav no longer shows a page `badge` note (language belongs in `language`, not a sidebar label)

## [1.2.1] — 2026-10-05

### Added

- GitHub Actions workflow publishes the gem to RubyGems when a release is published (`RUBYGEMS_API_KEY`)

### Fixed

- Refresh root `Gemfile.lock` for the 1.2 path gemspec (CI frozen `bundle install`)
- Run validate gates under `bundle exec` so Jekyll resolves in CI

## [1.2.0] — 2026-10-05

### Added

- Optional Expo Android Studio shell under `studio-mobile/` (git only; excluded from the gem)
- Env/EAS identity: `STUDIO_WEB_APP_URL`, `STUDIO_ANDROID_PACKAGE` / `ANDROID_PACKAGE`, `STUDIO_APP_NAME`, `EAS_PROJECT_ID` (example.com defaults)
- Docs: [docs/studio-android.md](docs/studio-android.md); CI workflow `studio-mobile.yml` (`npm ci && npm test`)

### Changed

- `pandorga new` pins `gem "pandorga", "~> 1.2"`

## [1.1.0] — 2026-10-05

### Added

- `pandorga new PATH` scaffolds a site from `examples/minimal` (`gem "pandorga", "~> 1.1"`)
- Listing runtimes read collection, listing path, and detail pattern from the registry page slot (dual template instances)

### Changed

- Generator injects `collection`, `listing_path`, `detail`, and `template` on listing pages
- Pinning docs prefer the RubyGems form when the gem is published

## [1.0.0] — 2026-10-05

### Added

- Configurable hero art via `pandorga.home.hero_art` (default `page/hero-default.html`)
- Registry-driven homepage bands (`site.data.pandorga_home_bands`)
- `pandorga.content.backend` (`static` | `r2` | `object_store` | `s3`) wired to the runtime
- S3-compatible publish (`S3_*` env aliases, `pandorga publish` → object-store sync)
- Template layout selection from the registry (`cv`, `articles`, `blog`, …)
- `studio.yml` for all seven templates; `pandorga studio-schema` composes Studio from the registry
- Template packages with README, fixtures, and screenshot placeholders (`PLT-AC-4`)
- Registry schema + generated `docs/configuration.md` (`PLT-AC-11`)
- CV public-export allowlist gate (`PLT-AC-7`)
- Gitleaks job in CI (`PLT-AC-1`)
- Deploy notes for Netlify and GitHub Pages (shell + static backend)
- Docs: architecture, pages-and-templates, theming, extending, upgrading
- Fictional content for `examples/full`

### Changed

- Home layout no longer hardcodes Portuguese CTAs or website kite art
- Blog listing UI uses English platform defaults and identity locale
- Export / content adapter / collections prefer `PandorgaRegistry` over fixed lists
- Docs drop v0.1.0-only deploy wording; Cloudflare doc notes host-agnostic shell

## [0.2.0] — 2026-10-05

### Added

- Full theme extract: `_layouts`, `_includes` (content-runtime), `_data`, assets
- Jekyll plugins migrated under `_plugins` / `lib/pandorga/jekyll/plugins`
- Content export pipeline, Studio build + Functions, `studio-app` source
- CLI `export` / `serve` delegate to the real pipeline (`PANDORGA_SITE_ROOT`)

## [0.1.0] — 2026-10-05

### Added

- Gem skeleton: page-registry generator, CLI stubs, examples, docs, CI
- ADR freeze for §13 owner decisions (`docs/decisions.md`)
