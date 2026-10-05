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
gem "pandorga", "~> 1.2"

# Or pin a GitHub release tag
gem "pandorga", github: "alexandrelheinen/pandorga", tag: "v1.2.0"
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

`pandorga new` pins `gem "pandorga", "~> 1.2"`. Publishing is automated: when a
GitHub Release is published, [`.github/workflows/publish-gem.yml`](../.github/workflows/publish-gem.yml)
builds the gem and runs `gem push`, provided the tag matches
`Pandorga::VERSION` (for example `v1.2.0`).

Set a repository secret named `RUBYGEMS_API_KEY` (RubyGems → Settings → API
keys, scope that can push gems). Until that secret exists, installs stay on the
GitHub tag pin above.

Manual publish (optional):

```bash
mise exec -- gem build pandorga.gemspec
mise exec -- gem push pandorga-1.2.0.gem
```

## Android shell (1.2+)

From 1.2.0 the git repository includes `studio-mobile/` (not packaged in the
gem). Clone the repo (or copy that tree), set `STUDIO_WEB_APP_URL` and related
env vars, run `eas init`, then build an APK — see
[studio-android.md](studio-android.md).
