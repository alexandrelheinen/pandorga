# Template: portfolio

Project catalogue rendered as a grid of system cards. One collection of
project entries with optional detail pages.

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id |
| `template` | Must be `portfolio` |
| `collection` | Projects folder under `content/collections/` |
| `path` | Listing URL |
| `detail` | Detail route pattern, for example `/projects/:slug/` |

Optional: `title`, `nav`, `home` (default limit 4).

## Collection contract

`title`, `key`, `sort_order`, `start_date`, `status`, `tags`, Markdown body.

## Configuration

```yaml
- key: projects
  template: portfolio
  title: Projects
  collection: projects
  path: /pages/projects/
  detail: /projects/:slug/
  nav: { group: Profile, icon: terminal }
  home: { limit: 4 }
```

## Package layout

- `template.yml` — slots, detail route, export fields
- `fixtures/` — minimal sample front matter
- `screenshots/` — capture notes (manual or CI later)
