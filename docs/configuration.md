# Configuration reference

Generated from `lib/pandorga/registry/schema.yml`. Gate: keep in sync
via `scripts/generate-configuration-doc.rb` (`PLT-AC-11`).

## `pandorga.identity`

| Key | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | Title suffix, default author, BibTeX. Also the legacy hero name when `first_name` or `last_name` is omitted |
| `first_name` | string | no | Hero given name and top-bar wordmark. Omitted or blank, the first word of `name` is used |
| `last_name` | string | no | Hero family name, kept whole (spaces allowed). Omitted or blank, the remainder of `name` is used |
| `short_name` | string | no | Shorter `<title>` suffix |
| `url` | string | no | Site canonical URL |
| `locale` | string | no | Default `en` |

## `pandorga.content`

| Key | Type | Notes |
|---|---|---|
| `backend` | `static` \| `r2` \| `object_store` \| `s3` | `static` serves JSON from `_site`. The others use `base_url` as the public object-store origin. Omitted plus a public URL selects `object_store` |
| `base_url` | string | Public content origin when backend is not `static` |

Legacy `content_api_base_url` still works as a fallback for `base_url`.
When `backend` is omitted, a non-empty `base_url` or `content_api_base_url` selects `object_store`. With no origin, the default is `static`. An explicit `backend: static` still serves JSON from `_site` and clears the public URL at build time.

## `pandorga.home`

| Key | Type | Notes |
|---|---|---|
| `hero_art` | string | Include path for hero decoration (default `page/hero-default.html`) |

## `pandorga.fonts`

| Key | Type | Notes |
|---|---|---|
| `title` | string or map | Display face. Default family `Cinzel Decorative`, weights 400, 700, and 900 |
| `body` | string or map | Reading face. Default family `Newsreader`, weights 300, 400, 500, 600, and 700 |
| `mono` | string or map | Monospace face. Default family `Courier Prime`, roman and italic at 400 and 700 |
| `label` | string or map | Optional chrome face. Default family `Marcellus SC`, weights 400 and 700 |
| `subtitle` | string or map | Optional tagline face. Omitted, it follows `body` when the theme used the same family |

Each value is a Google Fonts family name, or a map with `family` plus optional `weights` (integers) and `italic` (boolean). An omitted role keeps the Architectural Ledger face. `code` follows `mono`, and the tagline and CV body follow `body`, when the theme used one family for both. Text faces still load after the first paint, with `display=swap`. A `_data/themes/shared.yml` file remains the fallback under any role this map does not set.

## `pandorga.taxonomies`

Closed tag vocabularies per collection (`tags`, `max`, `min`). Page-local
`pandorga.pages[].taxonomy` is also accepted when a collection has no top-level
entry.

## `pandorga.pages[]`

| Key | Type | Required | Notes |
|---|---|---|---|
| `key` | string | yes | Unique page id |
| `template` | string | yes | One of `cv`, `articles`, `blog`, `media`, `network`, `bibliography`, `portfolio` |
| `layout` | string | no | Jekyll layout override (default from template) |
| `collection` / `collections` | string / map | template-dependent | Content folders |
| `path` | string | yes | Listing URL |
| `detail` | string | no | Detail route pattern |
| `nav` | map \| `false` | no | `{ group, icon }` or hide |
| `home` | map \| `false` | no | Home band options; omit for template defaults |
| `taxonomy` | map | no | Tag vocabulary for the page |
| `accent` | string | no | Page accent token |
| `language` | string | no | Listing chrome + dates (`en` default). Use `pt-BR` for Portuguese UI (e.g. blog / rascunhos) |

Duplicate `key`, unknown `template`, or conflicting `path` fails the build.

### `home` attributes

| Key | Notes |
|---|---|
| `band: hero` | Page feeds the hero (CV); not a separate band |
| `band: index` + `group` | Joins a shared index panel group |
| `featured` | Lead card for writing bands |
| `limit` | Max items in the band |
| `cta` | Listing CTA label (default `View all`) |
| `false` | Omit from the homepage |
