# Pandorga

A Jekyll publishing platform: static shell, content as JSON, page registry,
and Studio. The kite frame — your site is the paper.

Extracted from a personal site; this repository starts with a clean history
and contains no owner identity. Configuration belongs to each consuming site.

## Quickstart

Scaffold a site (Ada Example defaults, `content.backend: static`):

```bash
gem install pandorga   # once 1.1 is on RubyGems; or use a local checkout
pandorga new my-site
cd my-site
bundle install
bundle exec pandorga doctor
bundle exec pandorga serve
```

Or run the packaged minimal example from a clone:

```bash
git clone https://github.com/alexandrelheinen/pandorga.git
cd pandorga
git submodule update --init .guidelines   # agent/prose guidelines (optional for runtime)
mise install                              # or use Ruby >= 3.3
bundle install
cd examples/minimal && bundle install && cd ../..
bundle exec pandorga export examples/minimal/content examples/minimal/_content_json
bundle exec pandorga doctor examples/minimal
mise exec -- ./scripts/validate.sh
```

Serve from the example directory:

```bash
cd examples/minimal
bundle exec pandorga serve
```

## CLI

| Command | Purpose |
|---|---|
| `pandorga new PATH` | Scaffold a site from `examples/minimal` |
| `pandorga doctor` | Validate `pandorga:` config |
| `pandorga export` | Content → JSON (`manifest.json` includes `schema_version`) |
| `pandorga serve` | Export + `jekyll serve` |
| `pandorga publish` | S3-compatible object-store sync (`S3_*` or `R2_*`) |
| `pandorga install-functions` | Copy `functions/` + `studio/` into the site root |
| `pandorga studio-schema` | Compose Studio schema from templates |

## Documentation

| Doc | Topic |
|---|---|
| [docs/getting-started.md](docs/getting-started.md) | Minimal example locally |
| [docs/configuration.md](docs/configuration.md) | `pandorga:` reference |
| [docs/pages-and-templates.md](docs/pages-and-templates.md) | Registry and seven templates |
| [docs/theming.md](docs/theming.md) | `_data/themes` and tokens |
| [docs/extending.md](docs/extending.md) | Site overrides, hero art, Studio overrides |
| [docs/architecture.md](docs/architecture.md) | Shell, JSON, runtime, Studio |
| [docs/upgrading.md](docs/upgrading.md) | Semver, `schema_version`, gem pins |
| [docs/studio.md](docs/studio.md) | Studio env and schema compose |
| [docs/deploy/static.md](docs/deploy/static.md) | Static backend |
| [docs/deploy/cloudflare.md](docs/deploy/cloudflare.md) | Pages + object store |
| [docs/spec.md](docs/spec.md) | Migration plan and acceptance criteria |
| [docs/decisions.md](docs/decisions.md) | Frozen decisions |

## License

MIT — Copyright (c) The Pandorga contributors.
