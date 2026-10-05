# Template: articles

Writing collection rendered as a card grid with an optional featured item.
Shares the writing contract with `blog`; only presentation differs.

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id |
| `template` | Must be `articles` |
| `collection` | Writing collection folder under `content/collections/` |
| `path` | Listing URL |
| `detail` | Detail route pattern, for example `/articles/:slug/` |

Optional: `title`, `language`, `accent`, `nav`, `home`, `taxonomy`.

## Collection contract

`title`, `key`, `date`, `tags`, `language`, `thumbnail`, Markdown body.

## Configuration

```yaml
- key: articles
  template: articles
  collection: articles
  path: /pages/articles/
  detail: /articles/:slug/
```

The same template may be registered twice with different `key`, `collection`,
and `path` values. Each instance gets its own listing page.

## Package layout

- `template.yml` — slots, detail route, export fields
- `studio.yml` — Studio field schema for the collection slot
- `fixtures/` — minimal sample front matter
- `screenshots/` — capture notes (manual or CI later)
