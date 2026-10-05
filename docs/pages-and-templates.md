# Pages and templates

A site declares pages under `pandorga.pages` in `_config.yml`. The registry is
the single source for navigation, homepage bands, listing routes, export
collections, and Studio schema composition. Full field reference:
[configuration.md](configuration.md).

## How a page becomes a listing

1. You add an entry with `key`, `template`, and `path`.
2. The Jekyll generator validates the registry and emits a listing page when
   no on-disk page already owns that `key`.
3. `template` selects a known layout. You may set `layout` to override.

Order in the list is navigation and homepage order. Set `nav: false` or
`home: false` to omit a page from the menu or the homepage.

## The seven templates

| Template | Default layout | Typical collection | Detail route |
|---|---|---|---|
| `cv` | `cv` | `jobs`, `products`, profile data | products via CV flow |
| `articles` | `articles` | one writing collection | `/articles/:slug/` |
| `blog` | `blog` | one writing collection | `/posts/:slug/` |
| `media` | `resources` | `resources` | query-style resource view |
| `network` | `network` | none (`sources` page keys) | none |
| `bibliography` | `bibliography` | `bibliography` (+ `cited_by`) | none |
| `portfolio` | `projects` | `projects` | `/projects/:slug/` |

`articles` and `blog` share the writing contract (`title`, `key`, `date`,
`tags`, language, body). Presentation differs; both feed the writing index
when the exporter runs.

Site copy (Drafts, Sources, and similar labels) lives in content headers, not
in the template key. Keep URLs stable even when the label changes.

## Registry today, packages later

Sites use the registry plus Jekyll layouts today. Each template key maps to an
existing layout (`TEMPLATE_LAYOUTS` in `lib/pandorga/registry.rb`). Thin
metadata lives under `templates/<name>/` (`template.yml`, a short README;
`articles` also ships `studio.yml`).

Full template packages from the migration plan (§5.3) — per-template
`layout.html`, `home-band.html`, `runtime.js.html`, `style.css`, and fixtures —
are still evolving. Listing and detail behaviour still run through the shared
content runtime and the layouts above, not through self-contained template
modules.

## Examples

- `examples/minimal` — one `articles` page.
- `examples/full` — all seven templates with a fictional persona.
