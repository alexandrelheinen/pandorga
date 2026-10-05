# Deploy with the static backend

Set `pandorga.content.backend: static` and leave `base_url` empty. Run
`pandorga export` before `jekyll build` so `_content_json/` is copied into
`_site` (the gem enables `local_content_serve` for the static backend).

The public shell is host-agnostic: any static host works. Studio (the editor)
currently targets Cloudflare Pages Functions; you can ship the shell alone
without Studio.

Examples:

- [Netlify](netlify.md)
- [GitHub Pages](github-pages.md)
- Cloudflare Pages without R2 (shell only)
