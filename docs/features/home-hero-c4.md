# CR-22.4 — Home hero C4 (pandorga 2.3.6)

Status: shipped 2.3.6; contrast follow-up 2.3.7; desktop list rewrite 2.3.18  
Version target: pandorga 2.3.6 (contrast follow-up 2.3.7)  
Prerequisite: CR-22.3 (2.3.5) shipped.

## Intent

Ship the approved C4 mockups on top of B3: center the Projects island in the desktop column with equal left/right gaps; replace the hard spotlight with a darker soft edgeless photo overlay (no panel or box behind hero text); raise family-name highlighter to `--mk-h: 1.02em` with `padding-inline: 0.14em`; restore random hero photo picking when no pin is set, with crops at `50% 50%`; restyle hero CTAs as the site marker buttons (white ink allowed); when actions wrap, keep CV alone on line 1 and all contact buttons together on line 2. Everything else from 2.3.5 (CR-21g, 16:9 plates, limits 6/9, subtitle width, icon column = button width) stays unchanged.

## Acceptance criteria (EARS)

- `PLT-AC-88` From **1024px**, the Projects band’s inventory+specimen group (`.home-projects-bench`) and section banner **fill the projects column** (bench `width: 100%`, `margin-inline: 0`; banner stretch). Inventory rows are full-width list buttons (icon + name, ellipsis, height = `--home-icon-btn-size`); specimen plate is **+25%** (`15.3125rem` tall, 16:9) at ≥1440, with a narrow-desktop MQ (1024–1359) that keeps the list ≥8.5rem and scales the plate. Tablet 900–1023 keeps the prior centered icon-column island (`test-home-hero-c4`, `test-home-desk-layout`).
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
