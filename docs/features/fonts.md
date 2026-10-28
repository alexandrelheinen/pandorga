# Site font set

## Intent

A site that uses the theme should be able to name its own typefaces in
`_config.yml`. The Architectural Ledger faces stay in place when the site
says nothing.

## Scope

In:

- `pandorga.fonts.title`, `pandorga.fonts.body`, and `pandorga.fonts.mono`.
- Optional `pandorga.fonts.label` and `pandorga.fonts.subtitle`.
- A value is a Google Fonts family name, or a map with `family`, optional
  `weights`, and optional `italic`.
- Defaults: Ancizar Serif, Ancizar Sans, Marcellus SC, Courier Prime.
- Configurable `pandorga.fonts.body_weight` (default 300) and `pandorga.fonts.body_weight_mobile` (default 350).
- `_data/themes/shared.yml` remains the fallback under an omitted role.

Out:

- Self-hosted font files.
- A second font host. Requests stay on `fonts.googleapis.com`.
- Changing when the text faces load. Preconnect stays above the preload
  script. The stylesheet is still requested after the first paint, with
  `display=swap`.

## Acceptance criteria

- `PLT-AC-30` When `pandorga.fonts` is omitted, the system shall request
  the current faces (Ancizar Serif, Marcellus SC, Ancizar Sans, Courier
  Prime) and shall set those families on the type tokens. When a role is
  set, that role shall use the given Google Fonts family. Optional
  `weights` and `italic` shall be the only axis request for that family.
  A role that is omitted shall keep its current family. The text faces
  shall still load after the first paint, and the font hosts shall still
  be preconnected before the preload script (`test-fonts`,
  `test-hero-summary`).
- `PLT-AC-56` The default resolved stylesheet references exactly four families
  (Ancizar Serif, Ancizar Sans, Marcellus SC, Courier Prime) with no Cinzel.
- `PLT-AC-57` Body weights are site-configurable (`body_weight: 300`,
  `body_weight_mobile: 350`). Mobile query rebinds `--weight-body`.
- `PLT-AC-62` The home hero title container query clamps use Ancizar Serif
  factors at -0.02em tracking (~5.55em phone family-line width divisor, ~10.81em
  desktop full-name cap divisor).

## Constraints

The default stylesheet URL must stay the one the ledger already requests,
so an unset site does not download a different set of files. A family name
that would break the URL or the CSS variable is ignored and the role keeps
its fallback.

Known ledger and common site faces (Cinzel Decorative, Cinzel, Newsreader,
Ancizar Serif, Ancizar Sans, Marcellus SC) insert a metric-matched local fallback
from `assets/css/base.css` ahead of the generic stack, so `display=swap` does
not reflow the home hero. Do not move text faces back to a blocking head
link.
