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

### Section texts in `content/pages/headers.yml`

Each entry of `content/pages/headers.yml` is keyed by page key (`index` is the
home references band) and is written in that page's language. Studio edits
every field below from the Pages group (PLT-AC-50).

| Entry | Field | Where it shows | When the key is absent | When the value is empty |
|---|---|---|---|---|
| any page | `title`, `kicker`, `note` | page heading, and the home band title, kicker and note | the registry page title; no kicker or note | no kicker or note; `title` is the page heading and stays required in Studio |
| any page | `accent`, `tags` | page accent and heading tags | theme accent; no tags | no tags |
| any page with a home band | `cta` | the "View all" link of its home band | `pandorga.pages[].home.cta`, else "View all" | no link |
| `resources`, `network`, `bibliography` | `cta` | the "Open" link of its home panel | "Open" | no link |
| `resources`, `network`, `bibliography` | `note` | description under the panel title in the home references band | no description | no description |
| `resources`, `network`, `bibliography` | `title` | panel title in the home references band (also the page heading) | the registry page title | no panel title; the panel keeps the registry title as its accessible name |
| `projects` | `others_kicker`, `others_title` | banner above the project grid on the projects page | "Index", "Other projects" | empty kicker: no kicker; empty title: no banner |
| `projects` | `repositories_kicker`, `repositories_title` | banner above the repository list on the projects page | "Open source", "Repositories" | empty kicker: no kicker; empty title: no banner, and the list keeps "Repositories" as its accessible name |
| `cv` | `summary_title`, `experience_title`, `products_title`, `education_title`, `languages_title` | CV section headings | "Summary", "Experience", "Products", "Education", "Languages" | no heading; the section keeps the default as its accessible name |
| `cv` | `timeline_title` | timeline heading | "Timeline" | no heading row; the section keeps "Timeline" as its accessible name |
| `cv` | `contact_label` | the label over the contact links | "Contact" | no label |

**Absent versus empty.** A key that is missing, `null` or not a string is
absent: the theme default shows, so a site that never sets a field renders
what it rendered before. A key that holds an empty or whitespace-only string
is empty: the element is not rendered at all, with no empty wrapper or
separator left behind, and a hidden heading leaves its default as the
`aria-label` of the region it named. A home panel with neither title nor link
has no head row. The rule is the same at build time (Liquid, when
`site.data.page_headers` was read) and at run time (the content runtime, from
`pages/headers.json`, for `shell_content_agnostic` builds). Liquid tests these
keys against `nil`; `| default:` would treat an empty string as absent.

**`keep_empty`.** Studio normally drops empty optional fields on save. The
fields above are declared with `keep_empty: true` in `studio/schema.yml`, so
clearing one in the form saves `field: ''` instead of deleting the key. To
bring a default back, delete the line in the YAML source view. A field that
the editor never touches is not written, so an absent key stays absent.

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
