# Pandorga

[![CI](https://github.com/alexandrelheinen/pandorga/actions/workflows/validate.yml/badge.svg)](https://github.com/alexandrelheinen/pandorga/actions/workflows/validate.yml)
[![Release](https://img.shields.io/github/v/release/alexandrelheinen/pandorga)](https://github.com/alexandrelheinen/pandorga/releases/latest)
[![Gem Version](https://img.shields.io/gem/v/pandorga)](https://rubygems.org/gems/pandorga)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<img src="docs/images/family_link_64dp_5084C1_FILL0_wght400_GRAD0_opsz48.svg" alt="Pandorga Logo" width="120" align="left" style="margin-right: 10%;">
An aesthetic Jekyll publishing platform for creative and technical writing. The site is your paper, your portfolio, and an extension of your own thoughts.

- **Headless and S3-compatible.** Your content lives independently of the Pandorga shell — write, store, and move it on your own terms.
- **Studio CMS.** Manage everything from quick notes to full diagrams without touching the repo.
- **Fully configurable.** Portfolio, CV, blog, articles, and bibliography — each with its own presentation.

## Quickstart

Scaffold a site (Ada Example defaults, `content.backend: static`):

```bash
gem install pandorga   # or use a local checkout
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
| [docs/studio-android.md](docs/studio-android.md) | Optional Expo Android WebView shell |
| [docs/deploy/static.md](docs/deploy/static.md) | Static backend |
| [docs/deploy/cloudflare.md](docs/deploy/cloudflare.md) | Pages + object store |
| [docs/spec.md](docs/spec.md) | Migration plan and acceptance criteria |
| [docs/decisions.md](docs/decisions.md) | Frozen decisions |

## License

MIT — Copyright (c) The Pandorga contributors.
