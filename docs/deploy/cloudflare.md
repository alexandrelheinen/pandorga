# Deploy on Cloudflare Pages + R2

1. `gem "pandorga", github: "<owner>/pandorga", tag: "v0.1.0"`
2. Build command: `bundle exec pandorga install-functions && bundle exec jekyll build`
3. Publish content with `pandorga publish` (or the site R2 script) **before**
   shipping a shell that expects a new `schema_version`.
4. Set Pages secrets: `GITHUB_REPO`, `STUDIO_ALLOWED_ORIGINS`, Clerk keys.

Watch paths must include `Gemfile.lock` so gem bumps rebuild the shell.
