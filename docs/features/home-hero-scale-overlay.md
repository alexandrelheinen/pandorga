# CR-24 — Hero name vs band titles + lighter overlay (pandorga 2.3.10)

Status: shipping  
Version target: pandorga 2.3.11 (scale in 2.3.10; overlay tune 2.3.11)  
Prerequisite: 2.3.9 shipped.

## Intent

1. The home hero name (`h1.home-hero-title`) must **always** read slightly larger than home band titles (`h2.section-title` in `.home-band .ledger-section-banner`). Size the name from the **same type tokens** as those band titles (`--type-section` / `--type-section-lg`), plus a fixed **+2pt** (~2.67px), never from photo/`cqi`/`vw` clamps. The relationship holds at every width.
2. Soften the C4 hero photo overlay that 2.3.7 darkened too far: the figure must read clearly again, while worst-case title and summary contrast stays **≥ 7:1** (target ~9–11:1) for every pool photo at 390 and 1440, light and dark. Overlay stays soft and edgeless; no panel behind copy.

## Acceptance criteria (EARS)

- `PLT-AC-98` Below 768px, `.home-hero-title` uses `font-size: calc(var(--type-section) + 2pt)`; from 768px it uses `calc(var(--type-section-lg) + 2pt)`, matching the home band `.section-title` token step (`test-home-hero-scale`).
- `PLT-AC-99` At viewports 360, 390, 768, 1024, 1280, 1440, and 1920, computed `font-size(h1) − font-size(h2)` is in **[2.4, 3.0] px** (`test-home-hero-scale` structure; live verify).
- `PLT-AC-100` Soft edgeless `.home-hero-portrait::after` remains; `.home-hero-copy` stays `background: transparent`; overlay stops are lighter than 2.3.7–2.3.9 so the photo reads clearly while live worst-case title/summary contrast for every pool photo at 390/1440 light+dark stays ≥ 7:1 (`test-home-hero-scale`; live verify).

## Non-goals

- Do not change band title tokens or other 2.3.9 behavior (P3, marker CTAs, action icons, random pool).
- Do not cite the private website repository in pandorga docs or commits.
