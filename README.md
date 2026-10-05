# Pandorga

A Jekyll publishing platform: static shell, content as JSON, page registry,
and Studio. The kite frame — your site is the paper.

Extracted from a personal site; this repository starts with a clean history
and contains no owner identity. Configuration belongs to each consuming site.

## Quickstart (minimal example)

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

Serve locally (from a site directory that has a Gemfile):

```bash
cd examples/minimal
bundle exec pandorga serve
```

## CLI

| Command | Purpose |
|---|---|
| `pandorga doctor` | Validate `pandorga:` config |
| `pandorga export` | Content → JSON (`manifest.json` includes `schema_version`) |
| `pandorga serve` | Export + `jekyll serve` |
| `pandorga publish` | R2 sync (site script or env) |
| `pandorga install-functions` | Copy `functions/` + `studio/` into the site root |
| `pandorga studio-schema` | Compose Studio schema from templates |

## Spec

Migration and acceptance criteria: [docs/spec.md](docs/spec.md).  
Decisions: [docs/decisions.md](docs/decisions.md).

## License

MIT — Copyright (c) The Pandorga contributors.
