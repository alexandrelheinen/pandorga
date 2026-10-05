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

## Pin the gem by tag

Consumer sites should pin a release tag, not `main`:

```ruby
# Gemfile — RubyGems (preferred once published)
gem "pandorga", "~> 1.1"

# Or pin a GitHub release tag
gem "pandorga", github: "alexandrelheinen/pandorga", tag: "v1.1.0"
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

From 1.1.0, `pandorga new` pins `gem "pandorga", "~> 1.1"`. Publish a built
gem when you have a RubyGems API key:

```bash
mise exec -- gem build pandorga.gemspec
mise exec -- gem push pandorga-1.1.0.gem
```

Until the gem appears on RubyGems, sites can keep the GitHub tag pin shown
above. Android Studio remains a later minor (see [spec.md](spec.md) Phase 6).
