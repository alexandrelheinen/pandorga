# Template: cv

Public curriculum page: jobs, products, skills, education, and contacts from
data collections. Only fields listed in the contract leave the repository on
export (`body_public` and the allowlisted job fields).

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id (nav, headers, Studio) |
| `template` | Must be `cv` |
| `path` | Listing URL, for example `/pages/cv/` |
| `collections` | Map of slots: at least `jobs` and `products` (folder names under `content/collections/`) |

Optional: `title`, `nav`, `home` (default band is `hero`).

## Configuration

```yaml
- key: cv
  template: cv
  title: Curriculum Vitæ
  path: /pages/cv/
  collections: { jobs: jobs, products: products }
  nav: { group: Profile, icon: article_person }
  home: { band: hero }
```

## Package layout

- `template.yml` — slots and home defaults
- `fixtures/` — minimal sample front matter
- `screenshots/` — capture notes (manual or CI later)
