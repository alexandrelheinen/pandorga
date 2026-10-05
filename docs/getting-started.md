# Getting started

Run the minimal example without a Cloudflare account (`PLT-AC-6`).

## Prerequisites

- Ruby 3.3+ (3.4.4 via `mise` recommended)
- Bundler

## Five commands

```bash
git clone https://github.com/alexandrelheinen/pandorga.git
cd pandorga
bundle install
bundle exec pandorga export examples/minimal/content examples/minimal/_content_json
bundle exec pandorga doctor examples/minimal
```

Serve (needs a Gemfile in the example directory — already present):

```bash
cd examples/minimal && bundle install && bundle exec pandorga serve
```

Open `http://127.0.0.1:4000`. Content JSON is served from the same origin
(`content.backend: static`).

## Full example

`examples/full` declares all seven templates with a fictional persona. Same
flow; Studio env vars are optional and documented in [studio.md](studio.md).

## Next

- [configuration.md](configuration.md) — `pandorga:` reference
- [deploy/static.md](deploy/static.md) — publish without R2
- [deploy/cloudflare.md](deploy/cloudflare.md) — Pages + R2
