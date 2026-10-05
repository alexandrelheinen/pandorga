# AGENTS.md

Guidance for AI coding agents working in the **pandorga** platform repository.

@.guidelines/workflow/sdd.md
@.guidelines/workflow/integration.md
@.guidelines/workflow/tdd.md
@.guidelines/agents/writing.md
@.guidelines/style/naming.md
@.guidelines/languages/rb.md
@.guidelines/languages/js.md
@.guidelines/languages/sh.md

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/spec.md](docs/spec.md).
Decisions that freeze open questions live in [docs/decisions.md](docs/decisions.md).

## Quick reference

| Task | Command |
|---|---|
| Init guidelines submodule | `git submodule update --init .guidelines` |
| Run all gates | `mise exec -- ./scripts/validate.sh` |
| One gate | `mise exec -- ruby scripts/test/test-<name>.rb` |
| Doctor (example site) | `bundle exec pandorga doctor examples/minimal` |
| Export content JSON | `bundle exec pandorga export content _content_json` |
| Local serve | `cd examples/minimal && bundle exec pandorga serve` |
| Copy Functions for Pages | `bundle exec pandorga install-functions` |

## Architecture

One gem = Jekyll theme (`_layouts`, `_includes`, `assets`) + plugin
(`lib/pandorga/jekyll`) + CLI (`exe/pandorga`). Sites declare
`pandorga.pages` in `_config.yml`; the generator builds nav, listing pages,
and (later) redirects / Studio schema.

Examples under `examples/` use a fictional persona and `example.com` only.
Never commit owner identity, real R2 bucket IDs, or Clerk production keys.

## Constraints

- No Node build for the public site shell; Studio is the only Vite build.
- Content runtime stays a concatenated module when imported from a consumer site.
- Editorial include names (`figure.html`, `xcite.html`, …) stay at `_includes/` root.
- Field-backed rendering: no element without a supporting field.
- Traceability prefix: `PLT`.
