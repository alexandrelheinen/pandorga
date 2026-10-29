# Deploy on Cloudflare Pages + R2

The public shell is host-agnostic. Studio and Pages Functions are documented
here because that is the supported editor host today.

1. Pin the gem from RubyGems: `gem "pandorga", "~> 2.0"`.
   A Git pin uses the release you ship, for example `tag: "v2.2.5"`.
2. On Pages v3, set the Ruby version to 3.4.4 so Pages uses the image Ruby
   and does not compile a toolchain.
3. Pages runs `bundle install` before the build command. The build command
   is `bundle exec pandorga install-functions && bundle exec jekyll build`.
4. Set `SKIP_DEPENDENCY_INSTALL=1` when the repository contains a Python
   requirements file. Pages would otherwise pip-install those dependencies
   on every build.
5. Set `pandorga.content.backend: r2` (or `object_store`) and
   `pandorga.content.base_url` to the public bucket URL.
6. Publish content with `pandorga publish` **before** shipping a shell that
   expects a new `schema_version`. If CI calls the gem publish script through a
   site wrapper, export `PANDORGA_SITE_ROOT` to the site root first. Otherwise
   publish exits with an error (media would otherwise be skipped).
7. Set Pages secrets: `GITHUB_REPO`, `STUDIO_ALLOWED_ORIGINS`, Clerk keys.
   Object-store publish needs `S3_*` or legacy `R2_*` credentials
   (`S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`).

## Build watch paths

In Settings → Build → Build watch paths, include `*` so `Gemfile.lock` is
part of the build. Exclude `content/*` and `docs/*`. A content publish does
not need a Pages build: one listing shell loads the entry at runtime.
