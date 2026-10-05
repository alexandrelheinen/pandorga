# Deploy on Cloudflare Pages + R2

The public shell is host-agnostic. Studio and Pages Functions are documented
here because that is the supported editor host today.

1. Pin the gem: `gem "pandorga", git: "https://github.com/alexandrelheinen/pandorga", tag: "v1.0.0"`
2. Build command: `bundle exec pandorga install-functions && bundle exec jekyll build`
3. Set `pandorga.content.backend: r2` (or `object_store`) and
   `pandorga.content.base_url` to the public bucket URL.
4. Publish content with `pandorga publish` **before** shipping a shell that
   expects a new `schema_version`.
5. Set Pages secrets: `GITHUB_REPO`, `STUDIO_ALLOWED_ORIGINS`, Clerk keys.
   Object-store publish needs `S3_*` or legacy `R2_*` credentials
   (`S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`).

Watch paths must include `Gemfile.lock` so gem bumps rebuild the shell.
