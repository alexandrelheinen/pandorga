# Deploy the shell on Netlify

Use the static content backend (`pandorga.content.backend: static`). Netlify
hosts the Jekyll shell; content JSON ships inside `_site`.

## Build

```bash
bundle exec pandorga export content _content_json
bundle exec jekyll build
```

Publish directory: `_site`.

Studio (Clerk + Pages Functions) is not supported on Netlify in this release.
Ship the public site without `/studio/`, or keep Studio on Cloudflare Pages.
