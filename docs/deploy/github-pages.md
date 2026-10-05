# Deploy the shell on GitHub Pages

Use the static content backend (`pandorga.content.backend: static`).

## Build

```bash
bundle exec pandorga export content _content_json
bundle exec jekyll build
```

Publish the `_site` folder with the GitHub Pages action or a `gh-pages`
branch. Set `baseurl` / `url` in `_config.yml` to match the Pages site.

Studio is not supported on GitHub Pages in this release.