# Template: bibliography

Citation index built from a bibliography collection plus writings listed in
`cited_by`. No per-item detail route; the listing is the page.

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id |
| `template` | Must be `bibliography` |
| `collection` | Bibliography folder under `content/collections/` |
| `cited_by` | Array of writing page keys that cite entries |
| `path` | Listing URL |

Optional: `title`, `nav` (often `false`), `home` (default is a references
index panel).

## Collection contract

Bibliography data as BibTeX or JSON under the collection folder; writings
reference keys via includes such as `xcite`.

## Configuration

```yaml
- key: bibliography
  template: bibliography
  title: Bibliography
  collection: bibliography
  cited_by: [articles, blog]
  path: /pages/bibliography/
  nav: false
  home: { band: index, group: references }
```

## Package layout

- `template.yml` — slots and home defaults
- `fixtures/` — minimal sample bibliography JSON
- `screenshots/` — capture notes (manual or CI later)
