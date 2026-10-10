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
- Defaults: Cinzel Decorative, Newsreader, Courier Prime, Marcellus SC.
- `_data/themes/shared.yml` remains the fallback under an omitted role.

Out:

- Self-hosted font files.
- A second font host. Requests stay on `fonts.googleapis.com`.
- Changing when the text faces load. Preconnect stays above the preload
  script. The stylesheet is still requested after the first paint, with
  `display=swap`.

## Acceptance criteria

- `PLT-AC-30` When `pandorga.fonts` is omitted, the system shall request
  the current faces (Cinzel Decorative, Marcellus SC, Newsreader, Courier
  Prime) and shall set those families on the type tokens. When a role is
  set, that role shall use the given Google Fonts family. Optional
  `weights` and `italic` shall be the only axis request for that family.
  A role that is omitted shall keep its current family. The text faces
  shall still load after the first paint, and the font hosts shall still
  be preconnected before the preload script (`test-fonts`,
  `test-hero-summary`).

## Constraints

The default stylesheet URL must stay the one the ledger already requests,
so an unset site does not download a different set of files. A family name
that would break the URL or the CSS variable is ignored and the role keeps
its fallback.
