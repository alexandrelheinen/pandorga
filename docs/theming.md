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

For the full token inventory and design rules, see [DESIGN.md](../DESIGN.md)
in the repository root.
