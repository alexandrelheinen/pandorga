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

## Home band

The home band is a specimen bench: one featured project card beside a
filing rack of selectable project cards. Every element is backed by a
collection field; a missing field means a missing element.

- `PLT-AC-13` When the band renders, the specimen card shall carry a strip
  with the project's folio, `label`, `start_date` year and `status`; its
  16:9 `thumbnail` plate with the title set over it (or the 16:9 `icon` plate
  with the title below it); the `tagline`; the `tags`; and the outbound
  `github`, `article_url` and `external_url` links. The title is its only
  link to the project page.
- `PLT-AC-14` When a project lacks `thumbnail`, `icon`, `label`, `status`,
  `start_date`, `tagline`, `tags` or outbound links, the specimen card and its
  rack card shall render no element for that field.
- `PLT-AC-15` When the viewport is at least 900px wide, the specimen shall
  take half the band and the rack a narrower column beside it, leaving the
  rest blank. Each project shall appear in the rack as a card with its folio,
  `label`, `status`, title, `tagline` and a 16:9 `thumbnail` (or `icon`, or
  initial) mark. Selecting a card shall swap the specimen in place and mark
  that card `aria-pressed="true"`.
- `PLT-AC-16` Withdrawn: the tape of previous and next arrows was removed;
  the rack is the only way to change the specimen.
- `PLT-AC-17` When the viewport is narrower than 900px, the rack shall be a
  strip of icon buttons above the specimen, one per project (up to six), that
  together span the band's width.

`PLT-AC-13` and `-14` are covered by the block fixtures under
`scripts/test/render-parity/blocks/` and by the absent-field gate; `-15` and
`-17` are layout behavior verified in the browser.

## Package layout

- `template.yml` — slots, detail route, export fields
- `fixtures/` — minimal sample front matter
- `screenshots/` — capture notes (manual or CI later)
