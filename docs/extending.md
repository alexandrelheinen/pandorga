# Extending a site

Keep platform layouts untouched. Customize through the extension points below.
If another site would reuse the change, it belongs in the gem, not in a
one-off copy of a layout.

## Include overrides

Jekyll resolves an include from the site before the theme. Drop a file at the
same path under the site `_includes/` to replace the gem version. Example:
`_includes/page/hero-pandorga.html` for site-specific hero art.

## Hero art

Set the include path on the homepage slot:

```yaml
pandorga:
  home:
    hero_art: page/hero-pandorga.html
```

Default is `page/hero-default.html` (neutral SVG in the gem). The home layout
includes whatever path you give.

## Theme and translation data

Override `_data/themes/*.yml` as described in [theming.md](theming.md).
Override `_data/translations.yml` the same way when you need different shell
labels.

## Layout override per page

Registry entries accept `layout` when the default template layout is wrong for
that page. Prefer a documented template key when one fits.

## Studio schema overrides

Run `bundle exec pandorga studio-schema` in the site root. The command merges
each used template’s `studio.yml` with an optional `studio.overrides.yml`:

```yaml
# studio.overrides.yml
collections:
  articles:
    label: Essays
    fields:
      - name: title
        type: string
        required: true
```

Only templates that ship `studio.yml` contribute base fragments today
(`articles` does). Overrides fill gaps or replace collection entries by name.
See [studio.md](studio.md).

## What is not supported yet

Local `_templates/<name>/` packages, export registration hooks, and an
automatic `assets/css/site/` load path appear in the migration plan but are
not wired in the gem. Prefer include overrides and theme data until those
land.
