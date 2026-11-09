# CR-22.4 — Home hero C4 (pandorga 2.3.6)

Status: shipped 2.3.6; contrast follow-up 2.3.7; desktop list rewrite 2.3.18–2.3.20; contents page from 1024px (PLT-AC-88); gray selected wash + icon/name center + balanced padding (PLT-AC-104/105/106)  
Version target: pandorga 2.3.6 (contrast follow-up 2.3.7)  
Prerequisite: CR-22.3 (2.3.5) shipped.

## Intent

Ship the approved C4 mockups on top of B3: center the Projects island in the desktop column with equal left/right gaps; replace the hard spotlight with a darker soft edgeless photo overlay (no panel or box behind hero text); raise family-name highlighter to `--mk-h: 1.02em` with `padding-inline: 0.14em`; restore random hero photo picking when no pin is set, with crops at `50% 50%`; restyle hero CTAs as the site marker buttons (white ink allowed); when actions wrap, keep CV alone on line 1 and all contact buttons together on line 2. Everything else from 2.3.5 (CR-21g, 16:9 plates, limits 6/9, subtitle width, icon column = button width) stays unchanged.

## Acceptance criteria (EARS)

- `PLT-AC-88` **Contents.** From **1024px**, the Projects bench fills the padded column (`width: 100%`, `margin-inline: 0`) and the specimen card is not shown. The portfolio `.home-band-inner` keeps equal `--home-masthead-gutter` padding on all sides and vertically centers the banner+list block so empty space does not pool under the last name; the Projects column sets the masthead row height and the hero plate stretches to that height at full column width (PLT-AC-87). A collapsed row is a single grid track (icon + name) with even padding around the title — no empty second track under the name. The icon cell shows that glyph alone — no folio digits, label, or other meta text, and the cell must not overflow text. The name uses `--font-body` and `--weight-body` (Ancizar Sans, the theme dropdown face) at `calc(var(--type-body) + 2pt)`, with `white-space: normal` and no `text-overflow: ellipsis`. A name that exceeds the line wraps; none are truncated from 1024px to 1920px. Collapsed rows render no year and no tags. The selected row opens its 16:9 picture at `11rem` wide under the name. Beside that picture, when the row is wide enough to fit both the plate and a readable blurb, the row also shows the project's presentation text (`tagline` or listing preview) clamped to a few lines ending in an ellipsis and never cut mid-word without one; when the row is too narrow, only the picture is shown. Unselected rows show no picture and no blurb. Tablet 900–1023 keeps the centered icon-column island. Below 1024px the desktop contents extras stay out of view (`test-home-hero-c4`, `test-home-desk-layout`, `test-css-structure`, `test-regression-gate`).
- `PLT-AC-104` **Icon/name vertical center.** From 1024px, on every inventory row (selected and unselected), the vertical center of the project icon glyph bounding box and the vertical center of the project name text box differ by at most **1px** at 1024, 1280, 1440, and 1920 (`test-home-desk-layout`).
- `PLT-AC-105` **Selection highlight.** From 1024px the selected contents row uses only the existing hover surface `--color-surface-high` as a gray wash behind the whole row. No highlighter mark on the name, no drafting brackets around the row, no bordered icon square, and no `data-contents-select` switch. Unselected rows stay transparent. The selected name stays the body face with no mark background (`test-home-desk-layout`, `test-css-structure`).
- `PLT-AC-106` **Selected-row padding balance.** From 1024px, on the selected inventory row the space from the top of the gray wash to the top of the name equals the space from the bottom of the picture (or of the name when no picture) to the bottom of the wash within **1px**, at 1024, 1280, 1440, and 1920. When the excerpt sits beside the picture, both share the same top edge (top-aligned) inside that balanced outer padding (`test-home-desk-layout`).
- `PLT-AC-89` The hero portrait overlay (`.home-hero-portrait::after`) is a soft edgeless full-bleed darkening (no border-radius panel); `.home-hero-copy` stays `background: transparent` with no box/scrim pseudo-elements behind the text (`test-home-hero-c4`).
- `PLT-AC-90` Hero title and summary use light ink plus text-shadow on the soft overlay so worst-case contrast against every pool photo is at least 7:1 at all gated viewports and both themes (live verify; structure gated in `test-home-hero-c4`).
- `PLT-AC-91` `.home-hero-family` highlighter uses `--mk-h: 1.02em` and `padding-inline: 0.14em` (`test-home-hero-c4`).
- `PLT-AC-92` When `pandorga.home.hero_portrait` is unset, each load draws one pool entry via `Math.random`; every home hero/specimen/featured crop keeps computed `object-position: 50% 50%` / `center` (`test-hero-portraits`, `test-home-hero-c4`).
- `PLT-AC-93` Hero CTAs reuse `.ledger-cta--emphasis` / `--emphasis-alt` marker wash (no solid filled box override); white `--mark-ink` / label color is allowed on the photo (`test-home-hero-c4`).
- `PLT-AC-94` Hero actions wrap as two groups: CV alone on the first line when wrapping; all contact buttons stay together on the second line via `.home-hero-actions-contacts` (`flex-wrap: wrap` on actions, `nowrap` on the contacts group; hydrate writes contacts with `innerHTML`) (`test-home-hero-c4`).
- Prior CR-21…21g and CR-22…22.3 criteria remain green.

## Config

```yaml
pandorga:
  home:
    # Optional pin (stem or path fragment). Omit for random draw each load.
    # hero_portrait: DSC00571
    hero_overlay:
      strength: 0.60   # preferred; alias vignette
      pool: 0.94
```

Default behavior is random selection from `pages/home/portraits.json`. Sites that previously pinned a stem for mock parity should remove the pin to restore the random pool.

## Non-goals

- Do not cite the private website repository in pandorga docs or commits.
- No change to article/detail crop positions outside the home.
- No screenshots in the repository or release notes.
