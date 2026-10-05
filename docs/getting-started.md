# Getting started

Run a static-backend site without a Cloudflare account (`PLT-AC-6`).

## Prerequisites

- Ruby 3.3+ (3.4.4 via `mise` recommended)
- Bundler

## New site

`pandorga new` copies `examples/minimal` (fictional Ada Example) and pins the
gem at `~> 1.1`. Path and GitHub tag lines stay in the Gemfile as comments.

```bash
pandorga new my-site
cd my-site
bundle install
bundle exec pandorga doctor
bundle exec pandorga serve
```

Open `http://127.0.0.1:4000`. Content JSON is served from the same origin
(`pandorga.content.backend: static`).

## From a clone

```bash
git clone https://github.com/alexandrelheinen/pandorga.git
cd pandorga
bundle install
cd examples/minimal && bundle install
bundle exec pandorga export content _content_json
bundle exec pandorga doctor .
bundle exec pandorga serve
```

## Full example

`examples/full` declares all seven templates with a fictional persona. Same
flow; Studio env vars are optional and documented in [studio.md](studio.md).

## Next

- [configuration.md](configuration.md) — `pandorga:` reference
- [pages-and-templates.md](pages-and-templates.md) — registry and templates
- [theming.md](theming.md) / [extending.md](extending.md) — tokens and overrides
- [architecture.md](architecture.md) / [upgrading.md](upgrading.md) — layers and bumps
- [deploy/static.md](deploy/static.md) — publish without an object store
- [deploy/cloudflare.md](deploy/cloudflare.md) — Pages + R2
- [deploy/netlify.md](deploy/netlify.md) / [deploy/github-pages.md](deploy/github-pages.md) — shell hosts
