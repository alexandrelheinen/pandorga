# CR-24 — Hero name vs band titles + strength/pool overlay (pandorga 2.3.17)

Status: shipping  
Version target: pandorga 2.3.18  
Prerequisite: 2.3.16 shipped.

## Intent

1. The home hero name (`h1.home-hero-title`) must **always** read slightly larger than home band titles (`h2.section-title` in `.home-band .ledger-section-banner`). Size the name from the **same type tokens** as those band titles (`--type-section` / `--type-section-lg`), plus a fixed **+4pt** (~5.33px), never from photo/`cqi`/`vw` clamps. The relationship holds at every width.
2. Soft photo overlay with **independent** controls: `strength` darkens the photo area (face/figure stay readable); `pool` sets the absolute text-band alpha. Worst-case title and summary contrast stays **≥ 7:1** (aim ~8–10:1) for every pool photo at 390 and 1440, light and dark. No pure-black pixels from the overlay behind title/summary. Overlay stays soft and edgeless; no panel behind copy.

## Acceptance criteria (EARS)

- `PLT-AC-98` Below 768px, `.home-hero-title` uses `font-size: calc(var(--type-section) + 4pt)`; from 768px it uses `calc(var(--type-section-lg) + 4pt)`, matching the home band `.section-title` token step (`test-home-hero-scale`).
- `PLT-AC-99` At viewports 360, 390, 768, 1024, 1280, 1440, and 1920, computed `font-size(h1) − font-size(h2)` is in **[5.0, 5.7] px** (~4pt) (`test-home-hero-scale` structure; `test-home-desk-layout` rendered at 390/1440).
- `PLT-AC-100` Soft edgeless overlay; `.home-hero-copy` stays `background: transparent`; live worst-case title/summary contrast for every pool photo at 390/1440 light+dark stays ≥ 7:1 (`test-home-hero-scale`; live verify).
- `PLT-AC-101` When `pandorga.home.hero_overlay.strength` (or `vignette`) is set, the built home page emits that value as `--home-hero-vignette` on `:root` (`test-home-hero-overlay-strength`).
- `PLT-AC-102` `strength` and `pool` are independent: `::after` uses only `--home-hero-vignette` (masked off the text band); `::before` uses only `--home-hero-pool` as absolute alpha. Every stop is `min(cap, …)` with caps strictly &lt; 1. Pool paint uses charcoal `--home-hero-shade`. No `vignette / 0.6` overscale (`test-home-hero-overlay-split`).
- `PLT-AC-103` Strength darkens the photo area **monotonically and perceptibly**: `::after` paints **true black** `rgba(0,0,0,…)` (charcoal brightened dark photo regions in 2.3.16); peak coefficient ≥ 0.50; strength-cap ≥ 0.50 and &lt; 1. Rendered gate: upper/face mean-RGB drops ≥ 4 per 0.2 strength step across 0.2/0.4/0.6/0.8; text-band drops ≥ 4 per 0.2 pool step; independence; 0% pure-black in text band; at 390 and 1440 (`test-home-hero-overlay-monotonic`).

## Non-goals

- Do not change band title tokens or other 2.3.9 behavior (P3, marker CTAs, action icons, random pool).
- Do not cite the private website repository in pandorga docs or commits.

## Overlay strength / pool (config)

Sites set darkness under `pandorga.home.hero_overlay`:

```yaml
pandorga:
  home:
    hero_overlay:
      strength: 0.50   # 0–1; photo-area darkness (alias: vignette)
      pool: 0.66       # 0–1; absolute text-band alpha (not × strength)
```

Emitted on the home layout as `--home-hero-vignette` and `--home-hero-pool`. Soft `::after` (strength, true black) and `::before` (pool, charcoal) stops use `min(cap, …)`; gem defaults include `--home-hero-strength-cap: 0.55`, `--home-hero-pool-cap: 0.90`, and charcoal `--home-hero-shade` (pool only).
