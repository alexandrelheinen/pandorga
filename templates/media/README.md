# Template: media

Catalogue of external sources and media links (the site label is often
Sources). One collection of resource entries; detail is query-based
(`?resource=`).

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id |
| `template` | Must be `media` |
| `collection` | Resources folder under `content/collections/` |
| `path` | Listing URL |

Optional: `title`, `nav`, `home` (default is a references index panel).

## Collection contract

`title`, `key`, `link`, `medium`, `category`, optional body.

## Configuration

```yaml
- key: resources
  template: media
  title: Sources
  collection: resources
  path: /pages/sources/
  nav: { group: References, icon: media_link }
  home: { band: index, group: references }
```

## Package layout

- `template.yml` — slots and home defaults
- `fixtures/` — minimal sample front matter
- `screenshots/` — capture notes (manual or CI later)
