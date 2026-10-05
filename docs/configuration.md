# Configuration reference

Generated from `lib/pandorga/registry/schema.yml`. Gate: keep in sync
via `scripts/generate-configuration-doc.rb` (`PLT-AC-11`).

## `pandorga.identity`

| Key | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | Title suffix, default author, BibTeX |
| `short_name` | string | no | Shorter `<title>` suffix |
| `url` | string | no | Site canonical URL |
| `locale` | string | no | Default `en` |

## `pandorga.content`

| Key | Type | Notes |
|---|---|---|
| `backend` | `static` \| `r2` \| `object_store` \| `s3` | `static` serves JSON from `_site`. The others use `base_url` as the public object-store origin |
| `base_url` | string | Public content origin when backend is not `static` |

Legacy `content_api_base_url` still works as a fallback for `base_url`.

## `pandorga.home`

| Key | Type | Notes |
|---|---|---|
| `hero_art` | string | Include path for hero decoration (default `page/hero-default.html`) |

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
| `language` | string | no | Listing / home band language |

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
