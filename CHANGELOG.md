# Changelog

## [1.0.0] — 2026-10-05

### Added

- Configurable hero art via `pandorga.home.hero_art` (default `page/hero-default.html`)
- Registry-driven homepage bands (`site.data.pandorga_home_bands`)
- `pandorga.content.backend` (`static` | `r2` | `object_store` | `s3`) wired to the runtime
- S3-compatible publish (`S3_*` env aliases, `pandorga publish` → object-store sync)
- Template layout selection from the registry (`cv`, `articles`, `blog`, …)
- Deploy notes for Netlify and GitHub Pages (shell + static backend)
- Fictional content for `examples/full`

### Changed

- Home layout no longer hardcodes Portuguese CTAs or website kite art
- Export / content adapter / collections prefer `PandorgaRegistry` over fixed lists
- Docs drop v0.1.0-only deploy wording; Cloudflare doc notes host-agnostic shell

## [0.2.0] — 2026-10-05

### Added

- Full theme extract: `_layouts`, `_includes` (content-runtime), `_data`, assets
- Jekyll plugins migrated under `_plugins` / `lib/pandorga/jekyll/plugins`
- Content export pipeline, Studio build + Functions, `studio-app` source
- CLI `export` / `serve` delegate to the real pipeline (`PANDORGA_SITE_ROOT`)

## [0.1.0] — 2026-10-05

### Added

- Gem skeleton: page-registry generator, CLI stubs, examples, docs, CI
- ADR freeze for §13 owner decisions (`docs/decisions.md`)
