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

For the full token inventory and design rules, see [DESIGN.md](../DESIGN.md)
in the repository root.
