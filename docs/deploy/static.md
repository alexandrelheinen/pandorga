# Deploy with the static backend

Set `pandorga.content.backend: static` and leave `base_url` empty. Run
`pandorga export` before `jekyll build` so `_content_json/` is copied into
`_site` (or use `pandorga serve` locally).

Any static host works: GitHub Pages, Netlify, Cloudflare Pages without R2.
