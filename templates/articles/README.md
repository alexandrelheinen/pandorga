# Template: articles

Writing collection rendered as a card grid with an optional featured item.

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
