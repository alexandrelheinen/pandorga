# Configuration reference

Generated from the registry contract. Gate: keep in sync with
`lib/pandorga/registry.rb` (`PLT-AC-11`).

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
| `backend` | `r2` \| `static` | `static` serves JSON from `_site` |
| `base_url` | string | Public content origin when `r2` |

## `pandorga.pages[]`

| Key | Type | Required | Notes |
|---|---|---|---|
| `key` | string | yes | Unique page id |
| `template` | string | yes | One of `cv`, `articles`, `blog`, `media`, `network`, `bibliography`, `portfolio` |
| `layout` | string | no | Jekyll layout override |
| `collection` / `collections` | string / map | template-dependent | Content folders |
| `path` | string | yes | Listing URL |
| `detail` | string | no | Detail route pattern |
| `nav` | map \| `false` | no | `{ group, icon }` or hide |
| `home` | map \| `false` | no | Home band options |
| `taxonomy` | string | no | Key into `pandorga.taxonomies` |
| `accent` | string | no | Page accent token |

Duplicate `key`, unknown `template`, or conflicting `path` fails the build.
