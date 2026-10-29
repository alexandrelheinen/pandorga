# CR-22 — Home hero B3 (photo background, 50/50 masthead)

Status: shipped in 2.3.0  
Version target: pandorga 2.3.0  
Prerequisite: CR-21g (2.2.9) merged.

## Intent

Replace the home hero “copy | plate” desktop split with the approved B3 treatment: the portrait is the **background** of the hero panel; name, summary, and CTAs sit on the photo under a centered spotlight. On wide viewports the hero and Projects bands share the content width in **two equal columns** (projects start at the 50% line). Below that breakpoint the photo is full-bleed and stacked above Projects.

## Acceptance criteria (EARS)

- `PLT-AC-81` When the viewport is at least 1024px wide, the home ledger places `.home-band--hero` and the first `.home-band[data-home-kind="portfolio"]` in two columns of exactly 50% of the masthead content width each; the projects band’s left edge is within 1px of the content midpoint (`test-regression-gate`).
- `PLT-AC-82` When the viewport is at least 1024px wide, the hero portrait fills the hero panel (left column minus masthead gutter) as a covered background; copy (name, summary, three CTAs) is painted on the photo with no frosted panel; the name font size is the previous desktop size plus 2pt; the three hero CTAs share one row; family-name highlighter remains visible on the dark photo (`test-regression-gate`, `test-css-structure`).
- `PLT-AC-83` When the viewport is below 1024px, the hero photo spans the full viewport width (edge to edge); hero height hugs the copy plus modest top breathing (~74–85px from band top to name as in B3); Projects stacks below (`test-regression-gate`).
- `PLT-AC-84` A centered spotlight overlay (radial light pool at 50% 50% plus vignette) darkens the photo for text contrast while keeping the figure readable; overlay strength is config-driven via `pandorga.home.hero_overlay` (documented) (`test-css-structure`).
- `PLT-AC-85` Every cropped image on the home (hero plate, specimen/poster plates, featured posters) uses computed `object-position` / `background-position` of `50% 50%` (`center`) (`test-regression-gate`).
- Prior CR-21…21g criteria (PLT-AC-75…80) remain green. Specimen/thumbnail **plates** stay 16:9; the hero panel itself is a background panel (B3 ≈ 0.92 at 1440) and is **not** gated to 16:9.

## Config

```yaml
pandorga:
  home:
    hero_overlay:
      # Vignette darkness at the edges (0–1). Default 0.60.
      vignette: 0.60
      # How open the radial pool stays (0–1, higher = brighter figure). Default 0.94.
      pool: 0.94
```

Emitted as `--home-hero-vignette` and `--home-hero-pool` on `:root`.

## Non-goals

- No change to article/detail crop positions outside the home.
- Do not cite the private website repository in pandorga docs or commits.
