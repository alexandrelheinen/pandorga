# Theming

Colour and type tokens live in `_data/themes/`. The shell reads them at build
time and emits CSS variables. Do not hardcode hex values in layouts or
includes when a token already exists.

## Files

| File | Role |
|---|---|
| `_data/themes/light.yml` | Light palette (default Architectural Ledger colours) |
| `_data/themes/dark.yml` | Dark palette |
| `_data/themes/shared.yml` | Fonts, motion, and geometry shared by both palettes |

`theme-context.liquid` loads the active colour file plus `shared.yml`, so a
palette swap cannot drift the type stack.

## Choosing the active theme

Set `shell_theme` in the site `_config.yml`:

```yaml
shell_theme:
  active: system   # system | light | dark
  storage_key: site-theme
```

`system` follows the visitor preference and still ships both palettes. The
toggle writes the chosen name into `localStorage` under `storage_key`.

## Overriding from a site

Place `_data/themes/light.yml`, `dark.yml`, or `shared.yml` in the site root.
Jekyll merges site data over the theme gem, so your file replaces the gem
default for that name. Keep the same key shape (`colors`, `neutrals`,
`links`, and the shared `fonts` / `motion` / `geometry` maps).

## Fonts in site config

`pandorga.fonts` names the Google Fonts families for one site. A role you
leave out keeps the face in `shared.yml` (Cinzel Decorative, Newsreader,
Courier Prime, and Marcellus SC in the gem). A role you set wins over
that file.

| Key | Default family |
|---|---|
| `pandorga.fonts.title` | Cinzel Decorative |
| `pandorga.fonts.body` | Newsreader |
| `pandorga.fonts.mono` | Courier Prime |
| `pandorga.fonts.label` | Marcellus SC |
| `pandorga.fonts.subtitle` | the body face, when the theme used one family |

A value is a family name, or a map with `family`, optional `weights`, and
optional `italic`. The full example sets the default families so the
measured home requests the same files as an unset site. See
[configuration.md](configuration.md).

The font hosts stay preconnected. The text-face sheet is still inserted
after the first paint, with `display=swap`.

## Canvas

Every page sits on one ground (`PLT-AC-49`),
`--color-canvas`, and cards sit on it with the card surface
(`surface_card`). A palette may set `neutrals.canvas`; without it the
canvas is `neutrals.panel_contrast` (`#f4f4f4` light, `#141418` dark in the
gem). Keep the card surface and the canvas apart by at least one tonal step
so the hairline cards stay legible.

## Section accents in the navigation

Planned, not yet implemented (`PLT-AC-46`). When a section's listing page declares an `accent` (such as `green` or `ochre`), the desktop top-bar rail link for that section will apply `page-accent--<accent>` when active, tinting the active felt-pen mark with the section's accent color rather than the default blue. Detail pages within that section will inherit the same active rail link accent. Today the active rail mark stays blue in every section.

For the full token inventory and design rules, see [DESIGN.md](../DESIGN.md)
in the repository root.
