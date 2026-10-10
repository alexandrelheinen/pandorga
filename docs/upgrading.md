# Upgrading

Pandorga follows [Semantic Versioning](https://semver.org/). The gem version
is `Pandorga::VERSION` (`lib/pandorga/version.rb`).

## What bumps what

| Change | Version impact |
|---|---|
| Template contract, registry schema, or exported JSON shape | Major (or a deprecation window while still on a pre-1.x line) |
| New optional config, backward-compatible behaviour | Minor |
| Bug fix with no contract change | Patch |

Read [CHANGELOG.md](../CHANGELOG.md) before you bump.

## Font stylesheet (1.6.3)

No `pandorga:` keys were added. The hero summary is still the built HTML
from 1.6.2. The Google Fonts stylesheet is linked with the other sheets
again. Only the font preconnect stays above the preload script.

## Hero summary (1.6.2)

No `pandorga:` keys were added. When `content/pages/cv/summary.md` exists,
the home hero includes that markdown as HTML. Sites without the file keep
the quiet fragment. The body fallback is `Georgia, serif`.

## Discovery and portraits (1.6.0)

No `pandorga:` keys were added. The shell writes `/sitemap.xml` and
`/robots.txt`, and a `WebSite` / `Person` JSON-LD block. The sitemap origin
is `pandorga.identity.url`, then `site.url`.

A hero portrait object may set `srcset` and `sizes` next to `src`. Omit them
and the plate still uses `src` alone.

```json
{ "src": "/media/images/hero/plate.jpg", "srcset": "/media/images/hero/plate-800.jpg 800w, /media/images/hero/plate.jpg 1200w", "sizes": "(max-width: 767px) 100vw, 16rem" }
```

The hero subtitle stays at the body size (`--type-body`).

## Hero name (1.5.0)

`pandorga.identity.name` stays required. Two optional keys split the home
hero. `last_name` may contain spaces. The top bar shows `first_name`.

```yaml
pandorga:
  identity:
    name: "Ada Example"
    first_name: "Ada"
    last_name: "Example"
```

A site that only sets `name` keeps the 1.4.9 split. The first word is the
given name and the top-bar wordmark. The rest of `name`, up to eight words,
is the family name. Set the new keys when that split is wrong, for example
when the family name itself has more than one word. On a phone the hero
breaks only between those two fields.

When `first_name` is omitted, the top bar uses the first word of
`identity.name`, then `site.author`, then `site.title`.

The hero subtitle uses the body size (`--type-body`), the same size as the
summary under the name. Below 768px the name is 3pt larger than in 1.4.9.

See [features/hero-name.md](features/hero-name.md).

## Pin the gem by tag

Consumer sites should pin a release tag, not `main`:

```ruby
# Gemfile — RubyGems (preferred once published)
gem "pandorga", "~> 1.3"

# Or pin a GitHub release tag
gem "pandorga", github: "alexandrelheinen/pandorga", tag: "v1.3.11"
```

After a bump, run `bundle update pandorga` and commit `Gemfile.lock`. Host
watch paths must include `Gemfile.lock` so the shell rebuilds when the gem
moves.

During local platform work, `bundle config local.pandorga ../pandorga` points
Bundler at a checkout without editing the Gemfile.

## Content `schema_version`

Every export writes `schema_version` into `manifest.json` (currently `1`).
The content runtime refuses an unknown version and shows an explicit error
instead of rendering a broken page.

When a release raises the schema, publish content JSON **before** you ship a
shell that requires the new version. See [deploy/cloudflare.md](deploy/cloudflare.md)
for the Pages + object-store order.

## RubyGems

`pandorga new` pins `gem "pandorga", "~> 1.3"`. Publishing is automated: when a
GitHub Release is published, [`.github/workflows/publish-gem.yml`](../.github/workflows/publish-gem.yml)
pushes the gem via [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)
(OIDC; no long-lived API key). The release tag must match `Pandorga::VERSION`
(for example `v1.3.11`).

Site wrappers that `exec` the gem publish script **must** export
`PANDORGA_SITE_ROOT` to the Jekyll site root. Without it, publish exits with an
error instead of skipping `content/media` (Studio uploads would otherwise land
on GitHub only).

One-time setup on [RubyGems.org](https://rubygems.org):

1. Create a **pending** trusted publisher for gem name `pandorga`
   ([pending trusted publishers](https://rubygems.org/profile/oidc/pending_trusted_publishers)),
   pointing at [github.com/alexandrelheinen/pandorga](https://github.com/alexandrelheinen/pandorga)
   with workflow filename `publish-gem.yml` and environment `release`.
2. Ensure the GitHub Environment `release` exists on that repository
   (Settings → Environments).

After the first successful push, the pending publisher becomes a normal
trusted publisher for `pandorga`. Until then, installs stay on the GitHub tag
pin above.

Manual publish (optional, local MFA may apply):

```bash
mise exec -- gem build pandorga.gemspec
mise exec -- gem push pandorga-1.3.11.gem
```

## Android shell (1.2+)

From 1.2.0 the git repository includes `studio-mobile/` (not packaged in the
gem). Clone the repo (or copy that tree), set `STUDIO_WEB_APP_URL` and related
env vars, run `eas init`, then build an APK — see
[studio-android.md](studio-android.md).
