# Template: blog

Writing collection rendered as a dense ledger list with month bands and
folio numbers. Shares the writing contract with `articles`; only
presentation differs.

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id |
| `template` | Must be `blog` |
| `collection` | Writing collection folder under `content/collections/` |
| `path` | Listing URL |
| `detail` | Detail route pattern, for example `/posts/:slug/` |

Optional: `title`, `language`, `accent`, `nav`, `home`, `taxonomy`.

## Collection contract

`title`, `key`, `date`, `tags`, `language`, `thumbnail`, Markdown body.

## Configuration

```yaml
- key: blog
  template: blog
  title: Drafts
  collection: posts
  path: /pages/blog/
  detail: /posts/:slug/
```

## Package layout

- `template.yml` — slots, detail route, export fields
- `fixtures/` — minimal sample front matter
- `screenshots/` — capture notes (manual or CI later)
