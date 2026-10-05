# Template: network

Graph of writing connections derived from other registry pages. No collection
slot of its own; `sources` lists the page keys (or writing collections) whose
entries feed the graph.

## Required registry keys

| Key | Role |
|---|---|
| `key` | Page id |
| `template` | Must be `network` |
| `sources` | Array of page keys or writing collections to read |
| `path` | Listing URL |

Optional: `title`, `nav`, `home` (default is a references index panel).

## Configuration

```yaml
- key: network
  template: network
  title: Network
  sources: [articles, blog]
  path: /pages/network/
  nav: { group: References, icon: flowchart }
  home: { band: index, group: references }
```

## Package layout

- `template.yml` — sources contract and home defaults
- `fixtures/` — minimal sample JSON describing expected source keys
- `screenshots/` — capture notes (manual or CI later)
